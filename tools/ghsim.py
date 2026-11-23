"""Local stand-in for GitHub hosting, over HTTPS with a throwaway CA.

Port 8843 ("github.com" + "github.io"):
  /pages/...                                    static files (GitHub Pages layout)
  /U/R/releases/download/v1/<file>              302 -> https://<ip>:8844/asset/<file>?<1 KB signed-looking query>
Port 8844 ("release-assets.githubusercontent.com"):
  /asset/<file>?...                             the file, as application/octet-stream
Every request is logged to stdout.
"""
import http.server, ssl, sys, os, threading, secrets, urllib.parse

ROOT, TLS, IP = sys.argv[1], sys.argv[2], sys.argv[3]
REL = os.path.join(ROOT, 'rel', 'download', 'v1')


class Main(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **k):
        super().__init__(*a, directory=ROOT, **k)

    def do_GET(self):
        p = urllib.parse.urlsplit(self.path).path
        pre = '/U/R/releases/download/v1/'
        if p.startswith(pre):
            name = p[len(pre):]
            if not os.path.isfile(os.path.join(REL, name)):
                self.send_error(404); return
            q = 'sp=r&sv=2018-11-09&sig=' + secrets.token_urlsafe(700)
            self.send_response(302)
            self.send_header('Location', 'https://%s:8844/asset/%s?%s' % (IP, name, q))
            self.send_header('Content-Length', '0')
            self.end_headers(); return
        return super().do_GET()


class Asset(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        p = urllib.parse.urlsplit(self.path).path
        name = os.path.basename(p)
        f = os.path.join(REL, name)
        if not p.startswith('/asset/') or not os.path.isfile(f):
            self.send_error(404); return
        data = open(f, 'rb').read()
        self.send_response(200)
        self.send_header('Content-Type', 'application/octet-stream')
        self.send_header('Content-Length', str(len(data)))
        self.end_headers(); self.wfile.write(data)


def serve(port, handler):
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    ctx.minimum_version = ssl.TLSVersion.TLSv1_2
    ctx.load_cert_chain(os.path.join(TLS, 'srv.pem'), os.path.join(TLS, 'srv.key'))
    s = http.server.ThreadingHTTPServer(('0.0.0.0', port), handler)
    s.socket = ctx.wrap_socket(s.socket, server_side=True)
    s.serve_forever()


threading.Thread(target=serve, args=(8844, Asset), daemon=True).start()
serve(8843, Main)
