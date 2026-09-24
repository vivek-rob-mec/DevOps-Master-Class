import json,os
from http.server import BaseHTTPRequestHandler,ThreadingHTTPServer
from pathlib import Path
from delivery.flags import enabled

FLAGS=Path(os.getenv("FLAGS_FILE","/flags/governance.json"))

def checkout(targeting_key:str)->dict:
 flags=json.loads(FLAGS.read_text())
 use_v2=enabled(flags["checkout-v2"],targeting_key)
 return {"checkout":"v2" if use_v2 else "v1","targetingKey":targeting_key}

class Handler(BaseHTTPRequestHandler):
 def do_GET(self):
  if self.path=="/healthz":status,body=200,{"status":"ok"}
  elif self.path.startswith("/checkout"):
   status,body=200,checkout(self.headers.get("X-Targeting-Key","anonymous"))
  else:status,body=404,{"error":"not_found"}
  payload=json.dumps(body).encode();self.send_response(status);self.send_header("Content-Type","application/json");self.send_header("Content-Length",str(len(payload)));self.end_headers();self.wfile.write(payload)
 def log_message(self,format,*args):return

if __name__=="__main__":ThreadingHTTPServer(("0.0.0.0",int(os.getenv("PORT","8080"))),Handler).serve_forever()
