#!/usr/bin/env python3
"""Web 版を手元のブラウザで試すための、ちいさなサーバー。

    godot --headless --export-release "Web" build/web/index.html
    python3 tests/serve.py
    # → http://localhost:8000 を開く

Godot 4 の Web 版は SharedArrayBuffer を使うので、
Cross-Origin-Opener-Policy と Cross-Origin-Embedder-Policy が要る。
python3 -m http.server では、このヘッダーが付かないので起動しない。
"""
import functools
import http.server
import os
import sys

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8000
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "build", "web")


class Handler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        # この 2 つが無いと Godot 4 の Web 版は動かない。
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        # 書き出し直後の古い中身をつかまないように。
        self.send_header("Cache-Control", "no-store")
        super().end_headers()


if not os.path.isdir(ROOT):
    print("build/web がありません。先に書き出してください:")
    print('  godot --headless --export-release "Web" build/web/index.html')
    sys.exit(1)

print("http://localhost:%d を開いてください（止めるときは Ctrl-C）" % PORT)
http.server.ThreadingHTTPServer(
    ("127.0.0.1", PORT), functools.partial(Handler, directory=ROOT)
).serve_forever()
