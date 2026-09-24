from pyspark.sql import SparkSession, functions as F, types as T

spark = SparkSession.builder.appName("daily-order-metrics").master("local[*]").getOrCreate()
schema = T.StructType([
    T.StructField("event_id", T.StringType(), False),
    T.StructField("event_time", T.TimestampType(), False),
    T.StructField("customer_id", T.StringType(), False),
    T.StructField("country", T.StringType(), False),
    T.StructField("amount", T.DecimalType(18, 2), False),
    T.StructField("currency", T.StringType(), False),
])
orders = spark.read.schema(schema).json("/opt/platform/data/raw/orders.jsonl")
valid = orders.filter(F.col("event_id").isNotNull() & (F.col("amount") > 0)).dropDuplicates(["event_id"])
metrics = valid.withColumn("event_date", F.to_date("event_time")).groupBy("event_date", "country", "currency").agg(F.count("*").alias("order_count"), F.sum("amount").alias("gross_amount"))
if metrics.count() == 0:
    raise RuntimeError("quality gate failed: no valid order metrics")
metrics.write.mode("overwrite").partitionBy("event_date").parquet("/opt/platform/data/curated/daily-order-metrics")
spark.stop()
