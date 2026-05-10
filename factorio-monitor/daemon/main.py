from __future__ import annotations

import threading
import time

from config import load_config
from file_watcher import FileWatcher
from notifier import Notifier
from rcon_poller import RconConfig, RconPoller


def main() -> int:
    config = load_config()
    notifier = Notifier(config.discord_webhook_url)

    stop_event = threading.Event()

    watcher = FileWatcher(
        events_file=config.events_file,
        state_file=config.state_file,
        poll_interval_seconds=config.file_poll_interval_seconds,
        on_event=notifier.send_event,
        stop_event=stop_event,
    )

    poller = RconPoller(
        config=RconConfig(
            host=config.rcon_host,
            port=config.rcon_port,
            password=config.rcon_password,
        ),
        interval_seconds=config.poll_interval_seconds,
        on_state=notifier.send_state,
        stop_event=stop_event,
    )

    watcher.start()
    poller.start()

    try:
        while True:
            time.sleep(1.0)
    except KeyboardInterrupt:
        stop_event.set()
        watcher.join(timeout=5)
        poller.join(timeout=5)
        return 0


if __name__ == "__main__":
    raise SystemExit(main())

