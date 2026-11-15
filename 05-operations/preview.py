#!/usr/bin/env python3
"""Loopback-only handover preview; never exposes source or configuration."""
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.error import HTTPError
from urllib.parse import unquote, urlsplit
from urllib.request import Request, urlopen
import argparse

ROOT = Path(__file__).resolve().parents[1]
ROUTES = {
    '/mochi': ROOT / '01-release/web',
    '/downloads': ROOT / '01-release/android',
    '/presentation': ROOT / '04-presentation',
}

# Same-origin relay for local previews. The browser talks to 127.0.0.1, this
# script forwards to the gateway server-side, so the gateway never sees a
# foreign Origin and CORS cannot block the request.
AI_PREFIX = '/mochi-ai'
AI_UPSTREAM = 'https://bendocs.tailc1f51b.ts.net/mochi-ai'
AI_TIMEOUT_SECONDS = 45
FORWARDED_HEADERS = ('Authorization', 'Content-Type', 'Accept')


class Handler(SimpleHTTPRequestHandler):
    # Optional development build served at the site root instead of /mochi/.
    web_root = None

    def translate_path(self, path):
        path = unquote(urlsplit(path).path)
        for prefix, directory in ROUTES.items():
            if path == prefix or path.startswith(prefix + '/'):
                candidate = (directory / path[len(prefix):].lstrip('/')).resolve()
                if candidate.is_relative_to(directory.resolve()):
                    return str(candidate)
        if self.web_root is not None:
            candidate = (self.web_root / path.lstrip('/')).resolve()
            if candidate.is_relative_to(self.web_root.resolve()):
                return str(candidate)
        return str(ROOT / '__route_not_found__')

    def _proxy_ai(self, method):
        parts = urlsplit(self.path)
        target = AI_UPSTREAM + (parts.path[len(AI_PREFIX):] or '/')
        if parts.query:
            target += '?' + parts.query
        length = int(self.headers.get('Content-Length') or 0)
        body = self.rfile.read(length) if length else None
        request = Request(target, data=body, method=method)
        for header in FORWARDED_HEADERS:
            if self.headers.get(header):
                request.add_header(header, self.headers[header])
        try:
            with urlopen(request, timeout=AI_TIMEOUT_SECONDS) as upstream:
                payload = upstream.read()
                self.send_response(upstream.status)
                self._relay_headers(upstream.headers, len(payload))
                self.end_headers()
                self.wfile.write(payload)
        except HTTPError as error:
            payload = error.read()
            self.send_response(error.code)
            self._relay_headers(error.headers, len(payload))
            self.end_headers()
            self.wfile.write(payload)
        except Exception:
            payload = b'{"error":{"code":"proxy_failed"}}'
            self.send_response(502)
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self.send_header('Content-Length', str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)

    def _relay_headers(self, headers, length):
        self.send_header(
            'Content-Type',
            headers.get('Content-Type', 'application/json; charset=utf-8'),
        )
        self.send_header('Content-Length', str(length))

    def do_GET(self):
        path = urlsplit(self.path).path
        if path == AI_PREFIX or path.startswith(AI_PREFIX + '/'):
            self._proxy_ai('GET')
            return
        if path == '/' and self.web_root is None:
            self.send_response(302)
            self.send_header('Location', '/mochi/')
            self.end_headers()
            return
        super().do_GET()

    def do_POST(self):
        if urlsplit(self.path).path.startswith(AI_PREFIX + '/'):
            self._proxy_ai('POST')
            return
        self.send_error(405, 'Method not allowed')

    def do_OPTIONS(self):
        self.send_response(204)
        self.send_header('Allow', 'GET, POST, OPTIONS')
        self.end_headers()

    def end_headers(self):
        self.send_header('Cache-Control', 'no-cache')
        self.send_header('X-Content-Type-Options', 'nosniff')
        super().end_headers()

    def list_directory(self, path):
        self.send_error(403, 'Directory listing disabled')
        return None

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--port', type=int, default=8500)
    parser.add_argument(
        '--web-root',
        type=Path,
        help='Optional Flutter web build (base href /) served at the site root '
             'for local development, e.g. 02-source/flutter-app/build/web.',
    )
    args = parser.parse_args()
    if args.web_root is not None:
        path = args.web_root.resolve()
        if not (path / 'index.html').is_file():
            parser.error(f'{path} does not contain index.html')
        Handler.web_root = path
    server = ThreadingHTTPServer(('127.0.0.1', args.port), Handler)
    print(f'Mochii: http://127.0.0.1:{args.port}/mochi/', flush=True)
    if args.web_root is not None:
        print(f'Dev web: http://127.0.0.1:{args.port}/', flush=True)
    print(f'Slides: http://127.0.0.1:{args.port}/presentation/', flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
