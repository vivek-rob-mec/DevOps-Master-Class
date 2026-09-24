from datetime import datetime, timezone
import json, os, subprocess
from airflow.sdk import dag, task

@dag(dag_id="order_analytics_v1", schedule="@daily", start_date=datetime(2026, 1, 1, tzinfo=timezone.utc), catchup=False, max_active_runs=1, tags=["orders", "data-product"])
def order_analytics():
    @task(retries=2)
    def validate_contract():
        import sys
        sys.path.insert(0, "/opt/platform")
        from platform_lib.contracts import validate_file
        events = validate_file("/opt/platform/contracts/order-event.schema.json", "/opt/platform/data/raw/orders.jsonl")
        return len(events)

    @task(retries=3)
    def load_raw(expected_count):
        import psycopg
        sys_path = "/opt/platform"
        import sys
        sys.path.insert(0, sys_path)
        from platform_lib.contracts import validate_file
        events = validate_file(f"{sys_path}/contracts/order-event.schema.json", f"{sys_path}/data/raw/orders.jsonl")
        with psycopg.connect(os.environ["PLATFORM_DATABASE_URL"]) as connection:
            connection.execute("CREATE TABLE IF NOT EXISTS raw_orders(event_id uuid PRIMARY KEY,event_time timestamptz NOT NULL,customer_id varchar(64) NOT NULL,country char(2) NOT NULL,amount numeric(18,2) NOT NULL,currency char(3) NOT NULL,ingested_at timestamptz NOT NULL DEFAULT now())")
            for value in events:
                connection.execute("INSERT INTO raw_orders(event_id,event_time,customer_id,country,amount,currency) VALUES(%s,%s,%s,%s,%s,%s) ON CONFLICT(event_id) DO NOTHING", (value["event_id"], value["event_time"], value["customer_id"], value["country"], value["amount"], value["currency"]))
            count = connection.execute("SELECT count(*) FROM raw_orders").fetchone()[0]
        if count < expected_count:
            raise ValueError(f"quality gate failed: expected at least {expected_count}, found {count}")
        return count

    @task(retries=1)
    def transform(raw_count):
        subprocess.run(["dbt", "build", "--project-dir", "/opt/platform/dbt", "--profiles-dir", "/opt/platform/dbt", "--target-path", "/tmp/dbt-target", "--log-path", "/tmp/dbt-logs"], check=True)
        return {"raw_rows": raw_count, "dbt_status": "passed"}

    @task
    def publish_manifest(result):
        print(json.dumps({"data_product": "order_analytics_v1", **result}, sort_keys=True))

    publish_manifest(transform(load_raw(validate_contract())))

order_analytics()
