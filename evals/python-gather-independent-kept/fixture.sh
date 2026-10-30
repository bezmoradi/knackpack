#!/bin/bash
# A small notification service that fans one message out to email and SMS
# relays concurrently, committed with its delivery rules, plus an uncommitted
# change that adds a mobile push channel.
set -euo pipefail
git init -q
git config user.name "Eval Fixture"
git config user.email "fixture@example.com"
mkdir -p notify docs
touch notify/__init__.py
cat > pyproject.toml <<'TOML'
[project]
name = "notify"
version = "1.4.0"
requires-python = ">=3.11"
dependencies = ["httpx==0.27.2"]
TOML
cat > notify/channels.py <<'PY'
"""Delivery channels. Each posts the message to one internal relay."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Protocol

import httpx


@dataclass(frozen=True)
class Message:
    message_id: str
    recipient_id: str
    subject: str
    body: str


class Channel(Protocol):
    name: str

    async def send(self, message: Message) -> None: ...


class EmailChannel:
    name = "email"

    def __init__(self, client: httpx.AsyncClient, relay_url: str) -> None:
        self._client = client
        self._url = relay_url

    async def send(self, message: Message) -> None:
        response = await self._client.post(
            self._url,
            json={"to": message.recipient_id, "subject": message.subject, "text": message.body},
            headers={"Idempotency-Key": message.message_id},
        )
        response.raise_for_status()


class SmsChannel:
    name = "sms"

    def __init__(self, client: httpx.AsyncClient, gateway_url: str) -> None:
        self._client = client
        self._url = gateway_url

    async def send(self, message: Message) -> None:
        response = await self._client.post(
            self._url,
            json={"to": message.recipient_id, "text": message.subject},
            headers={"Idempotency-Key": message.message_id},
        )
        response.raise_for_status()
PY
cat > notify/fanout.py <<'PY'
"""Send one message on every channel."""

from __future__ import annotations

import asyncio
import logging
from collections.abc import Sequence

from notify.channels import Channel, Message

log = logging.getLogger(__name__)

SEND_TIMEOUT_SECONDS = 5


async def notify_all(message: Message, channels: Sequence[Channel]) -> list[str]:
    """Send message on every channel and return the names of those that failed.

    See docs/notifications.md: deliveries are independent, so one failing
    channel never stops the others.
    """
    failed: list[str] = []
    for channel in channels:
        try:
            async with asyncio.timeout(SEND_TIMEOUT_SECONDS):
                await channel.send(message)
        except Exception:
            log.warning(
                "delivery failed: channel=%s message=%s",
                channel.name,
                message.message_id,
                exc_info=True,
            )
            failed.append(channel.name)
    return failed
PY
cat > notify/registry.py <<'PY'
"""Which channels are active, from the environment."""

from __future__ import annotations

import os

import httpx

from notify.channels import Channel, EmailChannel, SmsChannel


def build_channels(client: httpx.AsyncClient) -> list[Channel]:
    return [
        EmailChannel(client, os.environ["EMAIL_RELAY_URL"]),
        SmsChannel(client, os.environ["SMS_GATEWAY_URL"]),
    ]
PY
cat > docs/notifications.md <<'MD'
# Notifications

`notify_all` sends a message on every active channel.

- Deliveries are independent. One channel failing or timing out must not
  cancel or delay the others, and must not fail the caller.
- Each send gets at most 5 seconds.
- `notify_all` returns the names of the channels that failed. The caller
  writes them to the outbox table, and the nightly retry job resends them.
  Every relay deduplicates on the `Idempotency-Key` header, so a resend after
  a timeout that actually delivered is harmless.
MD
git add -A
git commit -qm "Fan notifications out to email and SMS"
cat > notify/fanout.py <<'PY'
"""Send one message on every channel at once."""

from __future__ import annotations

import asyncio
import logging
from collections.abc import Sequence

from notify.channels import Channel, Message

log = logging.getLogger(__name__)

SEND_TIMEOUT_SECONDS = 5
MAX_CONCURRENT_SENDS = 8


async def send_one(channel: Channel, message: Message, limit: asyncio.Semaphore) -> None:
    async with limit:
        async with asyncio.timeout(SEND_TIMEOUT_SECONDS):
            await channel.send(message)


async def notify_all(message: Message, channels: Sequence[Channel]) -> list[str]:
    """Send message on every channel and return the names of those that failed.

    See docs/notifications.md: deliveries are independent, so one failing or
    slow channel never cancels the others.
    """
    limit = asyncio.Semaphore(MAX_CONCURRENT_SENDS)
    results = await asyncio.gather(
        *(send_one(channel, message, limit) for channel in channels),
        return_exceptions=True,
    )
    failed: list[str] = []
    for channel, result in zip(channels, results):
        if isinstance(result, BaseException):
            log.warning(
                "delivery failed: channel=%s message=%s",
                channel.name,
                message.message_id,
                exc_info=result,
            )
            failed.append(channel.name)
    return failed
PY
cat >> notify/channels.py <<'PY'


class PushChannel:
    name = "push"

    def __init__(self, client: httpx.AsyncClient, gateway_url: str) -> None:
        self._client = client
        self._url = gateway_url

    async def send(self, message: Message) -> None:
        # The gateway looks up the recipient's registered devices itself.
        response = await self._client.post(
            self._url,
            json={"to": message.recipient_id, "title": message.subject, "text": message.body},
            headers={"Idempotency-Key": message.message_id},
        )
        response.raise_for_status()
PY
cat > notify/registry.py <<'PY'
"""Which channels are active, from the environment."""

from __future__ import annotations

import os

import httpx

from notify.channels import Channel, EmailChannel, PushChannel, SmsChannel


def build_channels(client: httpx.AsyncClient) -> list[Channel]:
    channels: list[Channel] = [
        EmailChannel(client, os.environ["EMAIL_RELAY_URL"]),
        SmsChannel(client, os.environ["SMS_GATEWAY_URL"]),
    ]
    # Deployments without the mobile app leave PUSH_GATEWAY_URL unset.
    if push_url := os.environ.get("PUSH_GATEWAY_URL"):
        channels.append(PushChannel(client, push_url))
    return channels
PY
cat >> docs/notifications.md <<'MD'

## Channels

- `email` and `sms`: always on, through the internal relays.
- `push`: on when `PUSH_GATEWAY_URL` is set. The push gateway delivers to
  every device the recipient has registered.

With three channels, sends now run at the same time, at most 8 at once, so a
slow channel no longer delays the others.
MD
