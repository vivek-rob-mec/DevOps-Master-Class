import json, os
from confluent_kafka import Producer
from platform_lib.contracts import validate_file

schema = "/opt/platform/contracts/order-event.schema.json"
source = "/opt/platform/data/raw/orders.jsonl"
events = validate_file(schema, source)
producer = Producer({"bootstrap.servers": os.getenv("KAFKA_BOOTSTRAP_SERVERS", "kafka:9092"), "enable.idempotence": True, "acks": "all"})
for event in events:
    producer.produce("order-events.v1", key=event["customer_id"], value=json.dumps(event).encode())
remaining = producer.flush(15)
if remaining:
    raise RuntimeError(f"{remaining} messages were not delivered")
print(json.dumps({"published": len(events), "topic": "order-events.v1"}))
