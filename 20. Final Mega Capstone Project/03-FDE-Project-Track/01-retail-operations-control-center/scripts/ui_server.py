"""Browser-test server with a local file shutdown signal, no shutdown HTTP route."""
from pathlib import Path
import sys
import threading
import time

import uvicorn

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from app import create_app


if __name__ == '__main__':
    server = uvicorn.Server(uvicorn.Config(create_app(), host='127.0.0.1', port=int(sys.argv[1])))
    stop = Path(sys.argv[2])

    def watch():
        while not stop.exists():
            time.sleep(.1)
        server.should_exit = True

    threading.Thread(target=watch, daemon=True).start()
    server.run()
