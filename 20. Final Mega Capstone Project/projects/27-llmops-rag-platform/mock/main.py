import json
from http.server import BaseHTTPRequestHandler,ThreadingHTTPServer
class Handler(BaseHTTPRequestHandler):
 def do_POST(self):
  size=int(self.headers.get("Content-Length","0"));payload=json.loads(self.rfile.read(size) or b"{}")
  if self.path.endswith("/chat/completions"):body={"choices":[{"message":{"role":"assistant","content":"Refunds are available within thirty days [refund-policy]."}}],"usage":{"prompt_tokens":100,"completion_tokens":12}}
  else:body={"error":"not found"}
  data=json.dumps(body).encode();self.send_response(200 if "choices" in body else 404);self.send_header("Content-Type","application/json");self.send_header("Content-Length",str(len(data)));self.end_headers();self.wfile.write(data)
 def log_message(self,*args):return
ThreadingHTTPServer(("0.0.0.0",8000),Handler).serve_forever()
