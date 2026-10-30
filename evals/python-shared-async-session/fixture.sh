#!/bin/bash
# An async customer service built on SQLAlchemy's asyncio support: one async
# engine and session maker, with per-entity loaders. The uncommitted change
# adds a dashboard loader that fans the loaders out concurrently.
set -euo pipefail
git init -q
git config user.name "Eval Fixture"
git config user.email "fixture@example.com"
mkdir -p app

cat > pyproject.toml <<'TOML'
[project]
name = "dashboard-service"
version = "1.4.0"
requires-python = ">=3.11"
dependencies = [
    "sqlalchemy[asyncio]==2.0.36",
    "asyncpg==0.30.0",
]
TOML

cat > app/db.py <<'PY'
"""Async engine and session maker for the service."""

from __future__ import annotations

import os

from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)

DATABASE_URL = os.environ.get(
    "DATABASE_URL", "postgresql+asyncpg://localhost/app"
)

engine = create_async_engine(DATABASE_URL, pool_size=10, max_overflow=5)

SessionMaker = async_sessionmaker(engine, expire_on_commit=False, class_=AsyncSession)
PY

cat > app/models.py <<'PY'
"""ORM models for the customer dashboard."""

from __future__ import annotations

from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column


class Base(DeclarativeBase):
    pass


class Order(Base):
    __tablename__ = "orders"

    id: Mapped[int] = mapped_column(primary_key=True)
    customer_id: Mapped[str] = mapped_column(index=True)
    total_cents: Mapped[int] = mapped_column()
    status: Mapped[str] = mapped_column()


class Invoice(Base):
    __tablename__ = "invoices"

    id: Mapped[int] = mapped_column(primary_key=True)
    customer_id: Mapped[str] = mapped_column(index=True)
    amount_cents: Mapped[int] = mapped_column()
    paid: Mapped[bool] = mapped_column()


class Ticket(Base):
    __tablename__ = "tickets"

    id: Mapped[int] = mapped_column(primary_key=True)
    customer_id: Mapped[str] = mapped_column(index=True)
    subject: Mapped[str] = mapped_column()
    open: Mapped[bool] = mapped_column()
PY

cat > app/repos.py <<'PY'
"""Per-entity loaders for one customer."""

from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Invoice, Order, Ticket


async def load_orders(session: AsyncSession, customer_id: str) -> list[Order]:
    result = await session.execute(
        select(Order).where(Order.customer_id == customer_id)
    )
    return list(result.scalars())


async def load_invoices(session: AsyncSession, customer_id: str) -> list[Invoice]:
    result = await session.execute(
        select(Invoice).where(Invoice.customer_id == customer_id)
    )
    return list(result.scalars())


async def load_tickets(session: AsyncSession, customer_id: str) -> list[Ticket]:
    result = await session.execute(
        select(Ticket).where(Ticket.customer_id == customer_id)
    )
    return list(result.scalars())
PY

git add -A
git commit -qm "Add async engine, models and per-entity loaders"

cat > app/repos.py <<'PY'
"""Per-entity loaders for one customer, plus a combined dashboard loader."""

from __future__ import annotations

import asyncio

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Invoice, Order, Ticket


async def load_orders(session: AsyncSession, customer_id: str) -> list[Order]:
    result = await session.execute(
        select(Order).where(Order.customer_id == customer_id)
    )
    return list(result.scalars())


async def load_invoices(session: AsyncSession, customer_id: str) -> list[Invoice]:
    result = await session.execute(
        select(Invoice).where(Invoice.customer_id == customer_id)
    )
    return list(result.scalars())


async def load_tickets(session: AsyncSession, customer_id: str) -> list[Ticket]:
    result = await session.execute(
        select(Ticket).where(Ticket.customer_id == customer_id)
    )
    return list(result.scalars())


async def load_dashboard(session: AsyncSession, customer_id: str) -> dict:
    # Run the three loaders at once to cut dashboard latency: each is a
    # separate round trip, so overlapping them shortens the request.
    orders, invoices, tickets = await asyncio.gather(
        load_orders(session, customer_id),
        load_invoices(session, customer_id),
        load_tickets(session, customer_id),
    )
    return {"orders": orders, "invoices": invoices, "tickets": tickets}
PY
