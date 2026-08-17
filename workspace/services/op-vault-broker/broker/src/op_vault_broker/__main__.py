from __future__ import annotations

import asyncio
import logging
import signal
import sys

from .config import ConfigError, load_config
from .server import Broker


def _setup_logging() -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
        stream=sys.stdout,
    )


async def _run() -> None:
    try:
        config = load_config()
    except ConfigError as exc:
        logging.getLogger(__name__).error("config error: %s", exc)
        raise SystemExit(1) from exc

    broker = Broker(config)

    loop = asyncio.get_running_loop()
    serve_task = asyncio.ensure_future(broker.serve_forever())

    def _shutdown() -> None:
        serve_task.cancel()

    for sig in (signal.SIGTERM, signal.SIGINT):
        loop.add_signal_handler(sig, _shutdown)

    try:
        await serve_task
    except asyncio.CancelledError:
        pass


def main() -> None:
    _setup_logging()
    asyncio.run(_run())


if __name__ == "__main__":
    main()
