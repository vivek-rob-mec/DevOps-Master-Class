import json,threading
from http.server import BaseHTTPRequestHandler,HTTPServer
class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        body=json.dumps({"status":"ok","service":"logistics-worker"}).encode() if self.path=="/health" else b"not found";self.send_response(200 if self.path=="/health" else 404);self.send_header("Content-Type","application/json");self.send_header("Content-Length",str(len(body)));self.end_headers();self.wfile.write(body)
    def log_message(self,*args):pass
threading.Thread(target=HTTPServer(("0.0.0.0",8001),Handler).serve_forever,daemon=True).start()
from config.celery import app
app.worker_main(["worker","--loglevel=INFO","--concurrency=2"])
