import json,os
from http.server import BaseHTTPRequestHandler,ThreadingHTTPServer
class Handler(BaseHTTPRequestHandler):
 def do_GET(self):
  if self.path not in ("/health","/api/build-info"):self.send_error(404);return
  body=json.dumps({"status":"ok","revision":os.getenv("REVISION","dev")}).encode();self.send_response(200);self.send_header("Content-Type","application/json");self.send_header("Content-Length",str(len(body)));self.end_headers();self.wfile.write(body)
 def log_message(self,fmt,*args):print(json.dumps({"event":"http","message":fmt%args}))
if __name__=="__main__":ThreadingHTTPServer(("0.0.0.0",8080),Handler).serve_forever()
