"""Serve the roblox-vfx sim for this project WITHOUT writing into the skill folder.

    python assets/vfx/tools/serve_tfa.py [port]      # default 8766

- everything is served from the skill's sim/ (index.html, vfxsim.js, textures, meshes)
- /textures/tfa/<x>.png is served from assets/vfx/textures/<x>.png (this game's own textures,
  referenced in effect JSON as "sim:tfa/<x>")
- POST /save?name=x writes to assets/vfx/_out/x (strip.mjs moves it to strips/)
"""
import base64
import http.server
import os
import re
import sys
from pathlib import Path
from urllib.parse import parse_qs, urlparse

SIM = Path.home() / ".claude" / "skills" / "roblox-vfx" / "sim"
VFX = Path(__file__).resolve().parent.parent
TEX = VFX / "textures"
OUT = VFX / "_out"
SKELETON = ('<!doctype html><html><head><meta charset="utf-8">'
            '<meta name="viewport" content="width=device-width,initial-scale=1">'
            '<style>body{margin:0}</style></head><body>')


class H(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **k):
        super().__init__(*a, directory=str(SIM), **k)

    def translate_path(self, path):
        p = urlparse(path).path
        if p.startswith("/textures/tfa/"):
            return str(TEX / p[len("/textures/tfa/"):])
        return super().translate_path(path)

    def do_GET(self):
        if urlparse(self.path).path in ("/", "/index.html"):
            body = (SKELETON + (SIM / "index.html").read_text(encoding="utf-8") + "</body></html>").encode()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        super().do_GET()

    def do_POST(self):
        name = parse_qs(urlparse(self.path).query).get("name", ["frame.png"])[0]
        name = re.sub(r"[^A-Za-z0-9_.-]", "_", name)
        data = self.rfile.read(int(self.headers.get("Content-Length", 0))).decode()
        OUT.mkdir(parents=True, exist_ok=True)
        (OUT / name).write_bytes(base64.b64decode(data.split(",", 1)[-1]))
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"ok")

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def log_message(self, *a):
        pass


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8766
    print(f"http://127.0.0.1:{port}/", flush=True)
    http.server.ThreadingHTTPServer(("127.0.0.1", port), H).serve_forever()
