from __future__ import annotations

from dataclasses import dataclass
import json
import os
import random
import socket
import struct
import threading
import time
from typing import Any, Callable


_PACKET_TYPE_RESPONSE_VALUE = 0
_PACKET_TYPE_COMMAND = 2
_PACKET_TYPE_AUTH = 3


class RconError(RuntimeError):
    pass


@dataclass
class RconConfig:
    host: str
    port: int
    password: str
    timeout_seconds: float = 5.0


class RconClient:
    def __init__(self, config: RconConfig) -> None:
        self._config = config
        self._sock: socket.socket | None = None

    def connect(self) -> None:
        self.close()
        sock = socket.create_connection((self._config.host, self._config.port), timeout=self._config.timeout_seconds)
        sock.settimeout(self._config.timeout_seconds)
        self._sock = sock
        self._authenticate()

    def close(self) -> None:
        if self._sock is not None:
            try:
                self._sock.close()
            finally:
                self._sock = None

    def command(self, command: str) -> str:
        if self._sock is None:
            raise RconError("not connected")
        request_id = random.randint(1, 2**31 - 1)
        self._send_packet(request_id, _PACKET_TYPE_COMMAND, command)
        return self._read_response(request_id)

    def _authenticate(self) -> None:
        if self._sock is None:
            raise RconError("not connected")
        request_id = random.randint(1, 2**31 - 1)
        self._send_packet(request_id, _PACKET_TYPE_AUTH, self._config.password)

        # Servers may respond with multiple packets; auth failure uses id -1.
        deadline = time.time() + self._config.timeout_seconds
        authed = False
        while time.time() < deadline:
            pid, ptype, _payload = self._recv_packet()
            if ptype == _PACKET_TYPE_COMMAND:
                continue
            if pid == -1:
                raise RconError("authentication failed")
            if pid == request_id:
                authed = True
                break
        if not authed:
            raise RconError("authentication timed out")

    def _send_packet(self, request_id: int, packet_type: int, payload: str) -> None:
        if self._sock is None:
            raise RconError("not connected")
        data = payload.encode("utf-8") + b"\x00\x00"
        body = struct.pack("<ii", request_id, packet_type) + data
        packet = struct.pack("<i", len(body)) + body
        self._sock.sendall(packet)

    def _recv_exact(self, n: int) -> bytes:
        if self._sock is None:
            raise RconError("not connected")
        buf = b""
        while len(buf) < n:
            chunk = self._sock.recv(n - len(buf))
            if not chunk:
                raise RconError("connection closed")
            buf += chunk
        return buf

    def _recv_packet(self) -> tuple[int, int, str]:
        raw_len = self._recv_exact(4)
        (length,) = struct.unpack("<i", raw_len)
        raw_body = self._recv_exact(length)
        request_id, packet_type = struct.unpack("<ii", raw_body[:8])
        payload_bytes = raw_body[8:]
        # payload is NUL-terminated twice
        payload = payload_bytes[:-2].decode("utf-8", errors="replace")
        return request_id, packet_type, payload

    def _read_response(self, request_id: int) -> str:
        # Factorio generally returns one response packet for a command.
        deadline = time.time() + self._config.timeout_seconds
        chunks: list[str] = []
        while time.time() < deadline:
            pid, ptype, payload = self._recv_packet()
            if pid != request_id:
                continue
            if ptype == _PACKET_TYPE_RESPONSE_VALUE:
                chunks.append(payload)
                break
        return "".join(chunks).strip()


class RconPoller(threading.Thread):
    def __init__(
        self,
        config: RconConfig,
        interval_seconds: int,
        on_state: Callable[[dict[str, Any]], None],
        stop_event: threading.Event,
    ) -> None:
        super().__init__(name="rcon-poller", daemon=True)
        self._config = config
        self._interval_seconds = interval_seconds
        self._on_state = on_state
        self._stop_event = stop_event
        self._client = RconClient(config)

    def run(self) -> None:
        while not self._stop_event.is_set():
            try:
                self._poll_once()
            except Exception:
                self._client.close()
            self._stop_event.wait(self._interval_seconds)

    def _poll_once(self) -> None:
        if self._client._sock is None:
            self._client.connect()

        cmd = '/sc rcon.print(remote.call("factorio-monitor","get_state"))'
        payload = self._client.command(cmd)
        if not payload:
            return
        try:
            state = json.loads(payload)
        except json.JSONDecodeError:
            return
        if isinstance(state, dict):
            self._on_state(state)

