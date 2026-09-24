#!/usr/bin/env python3
"""
Minimal mock of the Gitea API endpoints that octojpack uses.

It only exists so the packaging flow can be tested end-to-end without a
real Gitea instance (see tests/run-local.sh and .github/workflows/test.yml).

Endpoints:
  GET  /health
  GET  /api/v1/repos/{owner}/{repo}/tags
  GET  /api/v1/repos/{owner}/{repo}/releases
  GET  /api/v1/repos/{owner}/{repo}/archive/{ref}.zip
  GET  /api/v1/repos/{owner}/{repo}/releases/download/{tag}/{asset}.zip
  GET  /LICENSE
  GET  /install.php
  GET  /config.json          (the tests/config.json file, served as a URL config)

Every unknown repository name returns a Gitea style error payload.
"""
import argparse
import io
import json
import os
import re
import sys
import zipfile
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse

TAG_VERSION = "v1.2.3"
RELEASE_VERSION = "v2.0.0"
BRANCH_VERSION = "3.0.0"

HERE = os.path.dirname(os.path.abspath(__file__))


def extension_zip(repo, ref, version, ext_type="component"):
    """Build a tiny Joomla extension zip with an extension XML (used for version detection)."""
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED) as zf:
        # fixed timestamps keep the archive bytes identical between runs (like a real tag archive)
        for name, data in (
            (f"{repo}/{repo}.xml",
             '<?xml version="1.0" encoding="utf-8"?>\n'
             f'<extension type="{ext_type}" version="4.0" method="upgrade">\n'
             f"\t<name>{repo}</name>\n"
             f"\t<version>{version}</version>\n"
             "</extension>\n"),
            (f"{repo}/README.md", f"# {repo} ({ref})\n"),
        ):
            info = zipfile.ZipInfo(name, date_time=(2021, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            zf.writestr(info, data)
    return buf.getvalue()


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):
        sys.stderr.write("[mock-gitea] " + (fmt % args) + "\n")

    def base_url(self):
        return "http://" + self.headers.get("Host", "127.0.0.1")

    def send_body(self, status, body, content_type):
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(body)

    def send_json(self, status, data):
        self.send_body(status, json.dumps(data).encode(), "application/json")

    def send_error_json(self, message):
        self.send_json(404, {"errors": [message], "message": message, "url": self.base_url() + "/api/swagger"})

    def do_HEAD(self):
        self.do_GET()

    def do_GET(self):
        path = urlparse(self.path).path

        if path == "/health":
            return self.send_body(200, b"ok\n", "text/plain")

        if path == "/LICENSE":
            with open(os.path.join(HERE, "licenses", "LICENSE"), "rb") as fh:
                return self.send_body(200, fh.read(), "text/plain")

        if path == "/install.php":
            return self.send_body(200, b"<?php\n// mock installation script\n", "text/plain")

        if path == "/config.json":
            with open(os.path.join(HERE, "config.json"), "rb") as fh:
                return self.send_body(200, fh.read(), "application/json")

        match = re.match(r"^/api/v1/repos/([^/]+)/([^/]+)/(tags|releases)$", path)
        if match:
            owner, repo, kind = match.groups()
            if repo.startswith("missing"):
                return self.send_error_json("The target couldn't be found.")
            if kind == "tags":
                return self.send_json(200, [{
                    "name": TAG_VERSION,
                    "message": f"Release {TAG_VERSION} of {repo}",
                    "commit": {"sha": "0000000000000000000000000000000000000000"},
                    "zipball_url": f"{self.base_url()}/api/v1/repos/{owner}/{repo}/archive/{TAG_VERSION}.zip",
                }])
            asset = f"{repo}_{RELEASE_VERSION}.zip"
            return self.send_json(200, [{
                "tag_name": RELEASE_VERSION,
                "name": f"Release {RELEASE_VERSION} of {repo}",
                "assets": [
                    {"name": "notes.txt", "browser_download_url": f"{self.base_url()}/notes.txt"},
                    {"name": asset,
                     "browser_download_url": f"{self.base_url()}/api/v1/repos/{owner}/{repo}/releases/download/{RELEASE_VERSION}/{asset}"},
                ],
            }])

        match = re.match(r"^/api/v1/repos/([^/]+)/([^/]+)/archive/(.+)\.zip$", path)
        if match:
            owner, repo, ref = match.groups()
            if repo.startswith("missing"):
                return self.send_error_json("The target couldn't be found.")
            version = ref[1:] if ref.startswith("v") else BRANCH_VERSION
            return self.send_body(200, extension_zip(repo, ref, version), "application/zip")

        match = re.match(r"^/api/v1/repos/([^/]+)/([^/]+)/releases/download/([^/]+)/(.+)\.zip$", path)
        if match:
            owner, repo, tag, asset = match.groups()
            return self.send_body(200, extension_zip(repo, tag, tag[1:], "plugin"), "application/zip")

        return self.send_error_json("Not found")


def main():
    parser = argparse.ArgumentParser(description="Mock Gitea API for octojpack tests")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=int(os.environ.get("MOCK_GITEA_PORT", "8765")))
    args = parser.parse_args()
    server = ThreadingHTTPServer((args.host, args.port), Handler)
    sys.stderr.write(f"[mock-gitea] listening on http://{args.host}:{args.port}\n")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
