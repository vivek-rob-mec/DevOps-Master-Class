"""Exercise installed Python/Node/Java runtimes without Docker; optional local check."""
import os
from pathlib import Path
import shutil
import socket
import subprocess
import sys
import tempfile

from smoke import check

ROOT = Path(__file__).resolve().parents[1]


def main():
    commands = {
        "python": [sys.executable, "app.py"],
        "node": ["node", "server.mjs"],
        "java": ["java", "App.java"],
    }
    for stack, command in commands.items():
        if not shutil.which(command[0]):
            print(f"SKIP: {stack} runtime unavailable")
            continue
        with socket.socket() as sock:
            sock.bind(("127.0.0.1", 0))
            port = sock.getsockname()[1]
        environment = dict(os.environ, PORT=str(port), APP_VERSION='test-"quoted"', APP_ENV="test")
        with tempfile.TemporaryFile(mode="w+") as log:
            process = subprocess.Popen(command, cwd=ROOT / "apps" / stack,
                                       env=environment, stdout=log, stderr=log)
            try:
                check(f"http://127.0.0.1:{port}", stack, environment["APP_VERSION"], "test")
            except Exception:
                log.seek(0)
                print(log.read())
                raise
            finally:
                process.terminate()
                try:
                    process.wait(timeout=30)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
    print("Native checks do not verify Gunicorn, Docker images, Go, .NET, or Kubernetes runtime behavior.")


if __name__ == "__main__":
    main()
