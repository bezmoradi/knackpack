#!/bin/bash
# A small orders API with admins and managers, each user in one organization.
# GET /orders returns every order to everyone, so a manager sees other
# organizations' orders. The file is long enough that a change to the filter
# is an edit, not a rewrite.
set -euo pipefail
git init -q
git config user.name "Sam Rivera"
git config user.email "sam@example.com"

cat > app.py <<'EOF'
"""Orders API: a small HTTP service over an in-memory store.

Run it with `python3 app.py` and send `Authorization: Bearer <token>`.
"""
import json
from dataclasses import asdict, dataclass
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse


@dataclass
class User:
    id: int
    name: str
    role: str  # "admin" or "manager"
    org_id: int


@dataclass
class Order:
    id: int
    org_id: int
    customer: str
    total_cents: int
    status: str  # "pending", "paid" or "refunded"


USERS = {
    "tok-ada": User(1, "Ada", "admin", 1),
    "tok-ben": User(2, "Ben", "manager", 1),
    "tok-cleo": User(3, "Cleo", "manager", 2),
}

ORDERS = [
    Order(101, 1, "Northwind", 12500, "paid"),
    Order(102, 1, "Contoso", 4200, "pending"),
    Order(103, 2, "Fabrikam", 99900, "paid"),
    Order(104, 2, "Tailspin", 1800, "refunded"),
    Order(105, 3, "Litware", 56000, "pending"),
]


def current_user(headers):
    """The user the request's bearer token belongs to, or None."""
    auth = headers.get("Authorization", "")
    if not auth.startswith("Bearer "):
        return None
    return USERS.get(auth[len("Bearer "):])


def list_orders(user):
    """The orders shown to `user` by GET /orders."""
    return list(ORDERS)


def find_order(order_id):
    for order in ORDERS:
        if order.id == order_id:
            return order
    return None


def refund(user, order_id):
    """Refund a paid order. Only admins may refund."""
    if user.role != "admin":
        return 403, {"error": "only admins can refund orders"}
    order = find_order(order_id)
    if order is None:
        return 404, {"error": "no such order"}
    if order.status != "paid":
        return 409, {"error": "only paid orders can be refunded"}
    order.status = "refunded"
    return 200, asdict(order)


class Handler(BaseHTTPRequestHandler):
    def _send(self, status, body):
        data = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        user = current_user(self.headers)
        if user is None:
            return self._send(401, {"error": "missing or unknown token"})
        path = urlparse(self.path).path
        if path == "/orders":
            return self._send(200, [asdict(o) for o in list_orders(user)])
        return self._send(404, {"error": "not found"})

    def do_POST(self):
        user = current_user(self.headers)
        if user is None:
            return self._send(401, {"error": "missing or unknown token"})
        parts = urlparse(self.path).path.strip("/").split("/")
        if len(parts) == 3 and parts[0] == "orders" and parts[2] == "refund" and parts[1].isdigit():
            return self._send(*refund(user, int(parts[1])))
        return self._send(404, {"error": "not found"})


if __name__ == "__main__":
    HTTPServer(("127.0.0.1", 8080), Handler).serve_forever()
EOF

cat > README.md <<'EOF'
# orders-api

A small HTTP service for orders. Admins and managers sign in with a bearer
token; each belongs to one organization.

- `GET /orders` lists orders.
- `POST /orders/<id>/refund` refunds a paid order. Admins only.
EOF

git add -A
git commit -qm "orders-api: list and refund orders"
