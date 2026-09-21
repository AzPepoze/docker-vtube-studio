#!/usr/bin/env python3
import functools
import http.server
import os

STREAM_DIR = os.environ.get("STREAM_DIR", "/srv/stream")
PORT = int(os.environ.get("STREAM_PORT", "8080"))

class Handler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {
        **http.server.SimpleHTTPRequestHandler.extensions_map,
        ".m3u8": "application/vnd.apple.mpegurl",
        ".ts": "video/mp2t",
    }

    def log_message(self, *args):
        pass

http.server.ThreadingHTTPServer(
    ("0.0.0.0", PORT), functools.partial(Handler, directory=STREAM_DIR)
).serve_forever()
