#!/usr/bin/env python3
import http.server, socketserver, json, webbrowser
from http.server import HTTPServer, SimpleHTTPRequestHandler

LOG_FILE = '/tmp/browser_logs.txt'

class LoggingHandler(SimpleHTTPRequestHandler):
    def log_message(self, format, *args):
        msg = f"[SERVER] {format % args}"
        print(msg)
        with open(LOG_FILE, 'a') as f: f.write(msg + '\n')
    def do_OPTIONS(self): self.send_response(200); self.end_headers()
    def do_POST(self):
        if self.path == '/log':
            length = int(self.headers['Content-Length'])
            data = self.rfile.read(length)
            try:
                log_entry = json.loads(data)
                print(f"[BROWSER] {log_entry.get('level','').upper()} {log_entry.get('event','')} {log_entry.get('data',{})}")
                with open(LOG_FILE, 'a') as f: f.write(f"[BROWSER] {json.dumps(log_entry)}\n")
            except: pass
            self.send_response(200); self.end_headers()
        else: super().do_POST()

if __name__ == '__main__':
    PORT = 8765
    with HTTPServer(('127.0.0.1', PORT), LoggingHandler) as httpd:
        print(f"✅ Server running at http://localhost:{PORT}")
        webbrowser.open(f'http://localhost:{PORT}/index.html')
        try: httpd.serve_forever()
        except KeyboardInterrupt: print("\n🛑 Server stopped. Logs saved to", LOG_FILE); httpd.shutdown()
