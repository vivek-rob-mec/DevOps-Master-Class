import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


def response_for(path: str) -> tuple[int, dict[str, str]]:
    if path == "/healthz":
        return 200, {"status": "ok"}
    return 404, {"error": "not_found"}


class Handler(BaseHTTPRequestHandler):
    def do_GET(self) -> None:
        status, body = response_for(self.path)
        payload = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, format: str, *args: object) -> None:
        return


if __name__ == "__main__":
    port = int(os.getenv("PORT", "8080"))
    ThreadingHTTPServer(("0.0.0.0", port), Handler).serve_forever()
