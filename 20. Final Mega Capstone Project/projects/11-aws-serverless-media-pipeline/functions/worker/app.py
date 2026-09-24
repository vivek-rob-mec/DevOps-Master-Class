import json,os,time

def process(message,media,ledger,now=None):
    required={"jobId","bucket","key"}
    if not required.issubset(message):raise ValueError("INVALID_MESSAGE")
    updated=int(now or time.time())
    if not ledger.claim(message["jobId"],updated):return
    try:
        metadata=media.inspect(message["bucket"],message["key"]);ledger.complete(message["jobId"],{"contentType":metadata.get("ContentType","application/octet-stream"),"size":int(metadata.get("ContentLength",0)),"etag":str(metadata.get("ETag","")).strip('"'),"updatedAt":int(now or time.time())})
    except Exception:
        ledger.fail(message["jobId"],int(time.time()));raise

class AwsMedia:
    def __init__(self,client):self.client=client
    def inspect(self,bucket,key):return self.client.head_object(Bucket=bucket,Key=key)
class AwsLedger:
    def __init__(self,table):self.table=table
    def claim(self,identifier,updated):
        try:self.table.update_item(Key={"jobId":identifier},UpdateExpression="SET #s=:processing,updatedAt=:updated",ConditionExpression="#s IN (:queued,:failed)",ExpressionAttributeNames={"#s":"status"},ExpressionAttributeValues={":processing":"processing",":queued":"queued",":failed":"failed",":updated":updated});return True
        except self.table.meta.client.exceptions.ConditionalCheckFailedException:return False
    def fail(self,identifier,updated):self.table.update_item(Key={"jobId":identifier},UpdateExpression="SET #s=:failed,updatedAt=:updated",ExpressionAttributeNames={"#s":"status"},ExpressionAttributeValues={":failed":"failed",":updated":updated})
    def complete(self,identifier,metadata):self.table.update_item(Key={"jobId":identifier},UpdateExpression="SET #s=:status,metadata=:metadata,updatedAt=:updated",ExpressionAttributeNames={"#s":"status"},ExpressionAttributeValues={":status":"completed",":metadata":metadata,":updated":metadata["updatedAt"]})

def handler(event,context):
    import boto3
    media=AwsMedia(boto3.client("s3"));ledger=AwsLedger(boto3.resource("dynamodb").Table(os.environ["JOBS_TABLE"]));failures=[]
    for record in event.get("Records",[]):
        try:process(json.loads(record["body"]),media,ledger)
        except Exception as error:
            print(json.dumps({"level":"error","messageId":record.get("messageId"),"message":str(error)}));failures.append({"itemIdentifier":record.get("messageId","")})
    return{"batchItemFailures":failures}
