import hashlib,json,os,time,uuid

def validate(payload):
    if not isinstance(payload,dict):raise ValueError("INVALID_BODY")
    bucket=str(payload.get("bucket","")).strip();key=str(payload.get("key","")).strip()
    if not 3<=len(bucket)<=63:raise ValueError("INVALID_BUCKET")
    if not key or len(key)>1024 or key.startswith("/") or ".." in key.split("/"):raise ValueError("INVALID_KEY")
    return {"bucket":bucket,"key":key}

def job_id(idempotency_key):return hashlib.sha256(idempotency_key.encode()).hexdigest()[:32]

def accept(payload,idempotency_key,ledger,queue,now=None):
    if not idempotency_key or len(idempotency_key)>128:raise ValueError("IDEMPOTENCY_KEY_REQUIRED")
    media=validate(payload);identifier=job_id(idempotency_key);created=int(now or time.time());job={"jobId":identifier,"status":"queued","bucket":media["bucket"],"key":media["key"],"createdAt":created,"updatedAt":created}
    ledger.put_if_absent(job);queue.send({"jobId":identifier,"bucket":media["bucket"],"key":media["key"],"correlationId":str(uuid.uuid4())})
    return ledger.get(identifier)

class AwsLedger:
    def __init__(self,table):self.table=table
    def put_if_absent(self,item):
        try:self.table.put_item(Item=item,ConditionExpression="attribute_not_exists(jobId)");return True
        except self.table.meta.client.exceptions.ConditionalCheckFailedException:return False
    def get(self,identifier):return self.table.get_item(Key={"jobId":identifier},ConsistentRead=True)["Item"]
class AwsQueue:
    def __init__(self,queue):self.queue=queue
    def send(self,item):
        request={"MessageBody":json.dumps(item)}
        if self.queue.url.endswith(".fifo"):request["MessageGroupId"]="media"
        self.queue.send_message(**request)

def handler(event,context):
    import boto3
    request_id=(event.get("requestContext")or{}).get("requestId") or getattr(context,"aws_request_id",str(uuid.uuid4()))
    try:
        body=json.loads(event.get("body")or"{}") if isinstance(event.get("body"),str) else event.get("body",{});key=(event.get("headers")or{}).get("idempotency-key") or (event.get("headers")or{}).get("Idempotency-Key")
        dynamo=boto3.resource("dynamodb").Table(os.environ["JOBS_TABLE"]);queue=boto3.resource("sqs").Queue(os.environ["QUEUE_URL"]);result=accept(body,key,AwsLedger(dynamo),AwsQueue(queue));return response(202,result,request_id)
    except (ValueError,json.JSONDecodeError) as error:return response(422,{"code":str(error)},request_id)
    except Exception as error:
        print(json.dumps({"level":"error","requestId":request_id,"message":str(error)}));return response(500,{"code":"INTERNAL_ERROR"},request_id)
def response(status,body,request_id):return{"statusCode":status,"headers":{"content-type":"application/json","x-request-id":request_id},"body":json.dumps(body)}
