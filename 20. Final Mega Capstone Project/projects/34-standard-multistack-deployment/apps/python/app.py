"""Portable WSGI application; the container runs it with Gunicorn."""
import json
import os


def app(environ, start_response):
    path = environ.get("PATH_INFO", "/")
    status, body = "200 OK", {"status": "ok"}
    if environ.get("REQUEST_METHOD") != "GET":
        status, body = "405 Method Not Allowed", {"error": "method not allowed"}
    elif path == "/api/info":
        body = {"service": "deployment-demo", "stack": "python",
                "version": os.getenv("APP_VERSION", "dev"),
                "environment": os.getenv("APP_ENV", "local")}
    elif path not in ("/healthz", "/readyz"):
        status, body = "404 Not Found", {"error": "not found"}
    payload = json.dumps(body).encode()
    headers = [("Content-Type", "application/json"), ("Content-Length", str(len(payload)))]
    if status.startswith("405"):
        headers.append(("Allow", "GET"))
    start_response(status, headers)
    print(json.dumps({"event": "request", "status": int(status[:3]), "stack": "python"}), flush=True)
    return [payload]


if __name__ == "__main__":
    # Dependency-free local verification only; use the Dockerfile for deployment.
    from wsgiref.simple_server import make_server
    make_server("127.0.0.1", int(os.getenv("PORT", "8080")), app).serve_forever()
