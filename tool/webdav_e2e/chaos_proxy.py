#!/usr/bin/env python3
"""FlashNote WebDAV E2E 故障注入代理（仅测试用）。

它把请求转发给真实的 WsgiDAV（默认 127.0.0.1:18081），并按路径前缀注入
真实网络层行为：

  /redirect/*  对任何方法返回 302，Location 指向上游真实地址
  /redirectput/* 仅对 PUT 返回 302，其余方法正常转发（验证“GET 成功但 PUT 被重定向”）
  /noetag/*    正常转发，但从响应中移除 ETag / Last-Modified
  /race/*      正常转发；收到 PUT 时先以“另一台设备”的身份无条件写一次正式文件，
               再转发原 PUT，使客户端在写入前复核时发现正式文件已变化
  /cut/*       正常转发；收到 PUT 时只把一半 body 发给上游，然后同时断开
               上下游连接，模拟上传途中断网（临时对象会被截断，正式文件不受影响）
  /nomove/*    对 MOVE 返回 405，其余方法正常转发，用于验证双槽位降级

用法：
  python tool/webdav_e2e/chaos_proxy.py
"""

import http.client
import json
import socket
import sys
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

UPSTREAM_HOST = "127.0.0.1"
UPSTREAM_PORT = 18081
LISTEN_HOST = "127.0.0.1"
LISTEN_PORT = 18082

PREFIXES = ("/redirectput", "/redirect", "/noetag", "/race", "/cut", "/nomove")
FINAL_PATH = "/FlashNote/flashnote_sync.json"

OTHER_DEVICE_SNAPSHOT = {
    "version": 6,
    "exportedAt": "2026-05-16T00:00:00.000",
    "inspirations": [
        {
            "id": 9001,
            "content": "另一台设备写入的灵感",
            "createdAt": 3000,
            "updatedAt": 3000,
            "isPinned": False,
        }
    ],
    "projects": [],
    "tasks": [],
    "customSources": [],
    "attachments": [],
    "chatMessages": [],
    "inspirationLinks": [],
    "clusters": [],
    "deletedRecords": [],
    "reports": [],
}
OTHER_DEVICE_BODY = json.dumps(OTHER_DEVICE_SNAPSHOT, ensure_ascii=False).encode("utf-8")


def split_route(path):
    for prefix in PREFIXES:
        if path == prefix or path.startswith(prefix + "/"):
            return prefix, path[len(prefix):] or "/"
    return None, path


def forward_headers(handler):
    return {
        key: value
        for key, value in handler.headers.items()
        if key.lower() not in ("host", "connection", "transfer-encoding")
    }


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):
        sys.stderr.write("[proxy] %s - %s\n" % (self.address_string(), fmt % args))
        sys.stderr.flush()

    # 所有 WebDAV 方法走同一入口
    do_GET = do_HEAD = do_PUT = do_MKCOL = do_DELETE = do_PROPFIND = do_OPTIONS = (
        lambda self: self._dispatch()
    )
    do_MOVE = lambda self: self._dispatch()

    def _read_body(self):
        length = int(self.headers.get("Content-Length") or 0)
        return self.rfile.read(length) if length else b""

    def _dispatch(self):
        prefix, upstream_path = split_route(self.path)

        if prefix == "/redirect":
            location = f"http://{UPSTREAM_HOST}:{UPSTREAM_PORT}{upstream_path}"
            self.send_response(302)
            self.send_header("Location", location)
            self.send_header("Content-Length", "0")
            self.end_headers()
            return

        if prefix == "/redirectput" and self.command == "PUT":
            body = self._read_body()
            location = f"http://{UPSTREAM_HOST}:{UPSTREAM_PORT}{upstream_path}"
            self.send_response(302)
            self.send_header("Location", location)
            self.send_header("Content-Length", "0")
            self.end_headers()
            return

        if prefix == "/nomove" and self.command == "MOVE":
            self._read_body()
            self.send_response(405)
            self.send_header("Content-Length", "0")
            self.end_headers()
            return

        body = self._read_body()

        if prefix == "/race" and self.command == "PUT":
            # 客户端先写临时对象；这里模拟另一台设备在写入窗口内改走正式文件。
            self._inject_other_device()

        if prefix == "/cut" and self.command == "PUT":
            self._cut_put(upstream_path, body)
            return

        self._forward(
            upstream_path,
            body,
            strip_validators=prefix == "/noetag",
            prefix=prefix,
        )

    def _inject_other_device(self):
        headers = forward_headers(self)
        headers["Content-Type"] = "application/json; charset=utf-8"
        headers["Content-Length"] = str(len(OTHER_DEVICE_BODY))
        # 注入的是无条件覆盖，不带客户端临时对象的条件头。
        for key in list(headers):
            if key.lower() in ("if-match", "if-none-match", "destination", "overwrite"):
                headers.pop(key)
        conn = http.client.HTTPConnection(UPSTREAM_HOST, UPSTREAM_PORT, timeout=10)
        try:
            conn.request("PUT", FINAL_PATH, body=OTHER_DEVICE_BODY, headers=headers)
            response = conn.getresponse()
            response.read()
            self.log_message(
                "race injection -> %s %s", response.status, response.reason
            )
        finally:
            conn.close()

    def _cut_put(self, path, body):
        conn = http.client.HTTPConnection(UPSTREAM_HOST, UPSTREAM_PORT, timeout=10)
        headers = forward_headers(self)
        # 关键：向上游声明完整长度，却只发送一半，模拟传输中断。
        headers["Content-Length"] = str(len(body))
        try:
            conn.putrequest(
                "PUT", path, skip_host=True, skip_accept_encoding=True
            )
            for key, value in headers.items():
                conn.putheader(key, value)
            conn.endheaders()
            conn.send(body[: len(body) // 2])
            # 先让客户端看到断连，再短暂等待上游开始写文件，最后断开上游。
            # WsgiDAV 直接以 "wb" 打开目标文件，头部到达后旧内容已被清空，
            # 因此这一步能稳定复现“远端半截文件”。
            self.close_connection = True
            try:
                self.connection.shutdown(socket.SHUT_RDWR)
            except OSError:
                pass
            time.sleep(0.3)
        finally:
            conn.close()
        self.log_message("cut PUT after %d/%d bytes", len(body) // 2, len(body))

    def _forward(self, path, body, strip_validators, prefix):
        headers = forward_headers(self)
        if body:
            headers["Content-Length"] = str(len(body))
        # MOVE 的 Destination 必须指向上游，并去掉代理路由前缀，否则
        # WsgiDAV 会把它当成跨服务器/不存在的目标并返回 409/502。
        for key in list(headers):
            if key.lower() == "destination":
                headers[key] = headers[key].replace(
                    f"http://{LISTEN_HOST}:{LISTEN_PORT}{prefix or ''}",
                    f"http://{UPSTREAM_HOST}:{UPSTREAM_PORT}",
                )
        conn = http.client.HTTPConnection(UPSTREAM_HOST, UPSTREAM_PORT, timeout=30)
        try:
            conn.request(self.command, path, body=body, headers=headers)
            response = conn.getresponse()
            self.send_response(response.status, response.reason)
            for key, value in response.getheaders():
                lower = key.lower()
                if lower in ("connection", "transfer-encoding"):
                    continue
                if strip_validators and lower in ("etag", "last-modified"):
                    continue
                self.send_header(key, value)
            self.end_headers()
            if self.command != "HEAD":
                while True:
                    chunk = response.read(8192)
                    if not chunk:
                        break
                    self.wfile.write(chunk)
        finally:
            conn.close()


def main():
    server = ThreadingHTTPServer((LISTEN_HOST, LISTEN_PORT), Handler)
    server.daemon_threads = True
    print(
        f"chaos proxy listening on http://{LISTEN_HOST}:{LISTEN_PORT} "
        f"-> http://{UPSTREAM_HOST}:{UPSTREAM_PORT}",
        flush=True,
    )
    server.serve_forever()


if __name__ == "__main__":
    main()
