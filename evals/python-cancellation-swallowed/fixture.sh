#!/bin/bash
# A small asyncio queue worker that reads jobs from a broker connection into a
# queue and processes them until shutdown, committed, plus an uncommitted
# change to how the consumer loop handles a failing message.
set -euo pipefail
git init -q
git config user.name "Eval Fixture"
git config user.email "fixture@example.com"
mkdir -p worker
touch worker/__init__.py
cat > pyproject.toml <<'TOML'
[project]
name = "job-worker"
version = "1.2.0"
requires-python = ">=3.11"
dependencies = []
TOML
cat > worker/broker.py <<'PY'
"""A line-based connection to the job broker: one JSON job per line in, ACK lines out."""

from __future__ import annotations

import asyncio
import json
from dataclasses import dataclass
from typing import Any


@dataclass(frozen=True)
class Message:
    message_id: str
    kind: str
    payload: dict[str, Any]


class Connection:
    def __init__(self, reader: asyncio.StreamReader, writer: asyncio.StreamWriter) -> None:
        self._reader = reader
        self._writer = writer

    async def receive(self) -> Message:
        line = await self._reader.readline()
        if not line:
            raise ConnectionError("broker closed the connection")
        raw = json.loads(line)
        return Message(message_id=raw["id"], kind=raw["kind"], payload=raw["payload"])

    async def ack(self, message_id: str) -> None:
        self._writer.write(f"ACK {message_id}\n".encode())
        await self._writer.drain()

    async def close(self) -> None:
        # Unacknowledged messages are redelivered once the broker sees the close.
        self._writer.close()
        await self._writer.wait_closed()


async def connect(host: str, port: int) -> Connection:
    reader, writer = await asyncio.open_connection(host, port)
    return Connection(reader, writer)
PY
cat > worker/handlers.py <<'PY'
"""What each kind of job does."""

import logging

from worker.broker import Message

log = logging.getLogger(__name__)


async def handle(message: Message) -> None:
    if message.kind == "resize_image":
        log.info("resizing %s", message.payload["path"])
    elif message.kind == "send_receipt":
        log.info("sending receipt for %s", message.payload["order_id"])
    else:
        raise ValueError(f"unknown job kind: {message.kind}")
PY
cat > worker/consumer.py <<'PY'
"""The consumer loop."""

import asyncio
import logging

from worker.broker import Connection, Message
from worker.handlers import handle

log = logging.getLogger(__name__)


async def run(queue: asyncio.Queue[Message], conn: Connection) -> None:
    """Process messages until cancelled, then close the broker connection."""
    try:
        while True:
            message = await queue.get()
            try:
                await handle(message)
                await conn.ack(message.message_id)
            finally:
                queue.task_done()
    finally:
        await conn.close()
PY
cat > worker/main.py <<'PY'
"""Process entry point. SIGTERM stops the reader, then the consumer."""

import asyncio
import contextlib
import os
import signal

from worker.broker import Connection, Message, connect
from worker.consumer import run


async def read_into(queue: asyncio.Queue[Message], conn: Connection) -> None:
    while True:
        await queue.put(await conn.receive())


async def main() -> None:
    conn = await connect(os.environ.get("BROKER_HOST", "localhost"), int(os.environ.get("BROKER_PORT", "7400")))
    queue: asyncio.Queue[Message] = asyncio.Queue(maxsize=100)
    reader = asyncio.create_task(read_into(queue, conn), name="reader")
    task = asyncio.create_task(run(queue, conn), name="consumer")

    stop = asyncio.Event()
    loop = asyncio.get_running_loop()
    for sig in (signal.SIGINT, signal.SIGTERM):
        loop.add_signal_handler(sig, stop.set)
    # Also shut down if the broker drops the connection; the supervisor restarts us.
    reader.add_done_callback(lambda _: stop.set())
    await stop.wait()

    reader.cancel()
    await asyncio.gather(reader, return_exceptions=True)
    task.cancel()
    with contextlib.suppress(asyncio.CancelledError):
        await task


if __name__ == "__main__":
    asyncio.run(main())
PY
git add -A
git commit -qm "Add the job worker"
cat > worker/consumer.py <<'PY'
"""The consumer loop."""

import asyncio
import logging

from worker.broker import Connection, Message
from worker.handlers import handle

log = logging.getLogger(__name__)


async def run(queue: asyncio.Queue[Message], conn: Connection) -> None:
    """Process messages until cancelled, then close the broker connection.

    One bad message must never kill the worker: whatever a handler raises is
    logged and the loop moves on to the next message. The failed message isn't
    acknowledged, so the broker redelivers it later.
    """
    try:
        while True:
            try:
                message = await queue.get()
                try:
                    await handle(message)
                    await conn.ack(message.message_id)
                finally:
                    queue.task_done()
            except BaseException:
                log.exception("message failed")
                continue
    finally:
        await conn.close()
PY
