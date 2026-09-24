import os,sys,unittest
sys.path.insert(0,os.path.join(os.path.dirname(__file__),"..","functions","intake"));import app as intake
sys.path.pop(0);sys.modules.pop("app",None);sys.path.insert(0,os.path.join(os.path.dirname(__file__),"..","functions","worker"));import app as worker
class Ledger:
    def __init__(self):self.data={}
    def put_if_absent(self,item):
        if item["jobId"] in self.data:return False
        self.data[item["jobId"]]=item;return True
    def get(self,key):return self.data[key]
    def claim(self,key,updated):
        if self.data[key]["status"] not in {"queued","failed"}:return False
        self.data[key].update(status="processing",updatedAt=updated);return True
    def fail(self,key,updated):self.data[key].update(status="failed",updatedAt=updated)
    def complete(self,key,metadata):self.data[key].update(status="completed",metadata=metadata)
class Queue:
    def __init__(self):self.messages=[]
    def send(self,item):self.messages.append(item)
class Media:
    def inspect(self,bucket,key):return{"ContentType":"image/png","ContentLength":42,"ETag":"abc"}
class PipelineTests(unittest.TestCase):
    def test_duplicate_intake_is_stable_and_retry_safe(self):
        ledger,queue=Ledger(),Queue();first=intake.accept({"bucket":"media-dev","key":"uploads/a.png"},"same",ledger,queue,1);second=intake.accept({"bucket":"media-dev","key":"uploads/a.png"},"same",ledger,queue,2);self.assertEqual(first["jobId"],second["jobId"]);self.assertEqual(2,len(queue.messages))
    def test_worker_completes_job(self):
        ledger,queue=Ledger(),Queue();job=intake.accept({"bucket":"media-dev","key":"uploads/a.png"},"key",ledger,queue,1);worker.process(queue.messages[0],Media(),ledger,2);self.assertEqual("completed",ledger.data[job["jobId"]]["status"])
    def test_path_traversal_is_rejected(self):
        with self.assertRaisesRegex(ValueError,"INVALID_KEY"):intake.validate({"bucket":"media-dev","key":"../secret"})
if __name__=="__main__":unittest.main()
