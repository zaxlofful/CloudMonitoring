from __future__ import annotations

from dataclasses import dataclass
import json
import os
from pathlib import Path
import threading
import time
from typing import Any, Callable


@dataclass
class TailState:
    inode: int | None = None
    offset: int = 0


def _load_state(path: Path) -> TailState:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        inode = data.get("events_inode")
        offset = int(data.get("events_offset", 0))
        return TailState(inode=inode, offset=offset)
    except FileNotFoundError:
        return TailState()
    except Exception:
        return TailState()


def _save_state(path: Path, state: TailState) -> None:
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(
        json.dumps(
            {"events_inode": state.inode, "events_offset": state.offset},
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    os.replace(tmp, path)


class FileWatcher(threading.Thread):
    def __init__(
        self,
        events_file: Path,
        state_file: Path,
        poll_interval_seconds: float,
        on_event: Callable[[dict[str, Any]], None],
        stop_event: threading.Event,
    ) -> None:
        super().__init__(name="file-watcher", daemon=True)
        self._events_file = events_file
        self._state_file = state_file
        self._poll_interval_seconds = poll_interval_seconds
        self._on_event = on_event
        self._stop_event = stop_event
        self._state = _load_state(state_file)

    def run(self) -> None:
        while not self._stop_event.is_set():
            try:
                self._tick()
            except Exception:
                time.sleep(self._poll_interval_seconds)

    def _tick(self) -> None:
        if not self._events_file.exists():
            time.sleep(self._poll_interval_seconds)
            return

        stat = self._events_file.stat()
        inode = stat.st_ino
        size = stat.st_size

        if self._state.inode is None:
            self._state.inode = inode
        if inode != self._state.inode:
            self._state.inode = inode
            self._state.offset = 0
        if size < self._state.offset:
            self._state.offset = 0

        with self._events_file.open("rb") as f:
            f.seek(self._state.offset)
            for raw_line in f:
                self._state.offset = f.tell()
                line = raw_line.decode("utf-8", errors="replace").strip()
                if not line:
                    continue
                try:
                    event = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if isinstance(event, dict):
                    self._on_event(event)

        _save_state(self._state_file, self._state)
        time.sleep(self._poll_interval_seconds)

