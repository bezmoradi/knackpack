#!/bin/bash
# A small React app whose order list shows nothing while it loads and nothing
# when the request fails. The user asks for a loading and an error state,
# which is a change, not a React review.
set -euo pipefail
git init -q -b main
git config user.name "Ines Duarte"
git config user.email "ines@example.com"
mkdir -p src
cat > package.json <<'JSON'
{
  "name": "orders-web",
  "private": true,
  "type": "module",
  "scripts": { "dev": "vite", "build": "vite build" },
  "dependencies": { "react": "19.1.0", "react-dom": "19.1.0" },
  "devDependencies": { "vite": "7.0.0", "@vitejs/plugin-react": "5.0.0" }
}
JSON
cat > src/OrderList.jsx <<'JSX'
import { useEffect, useState } from "react";

export function OrderList({ customerId }) {
  const [orders, setOrders] = useState([]);

  useEffect(() => {
    let cancelled = false;
    fetch(`/api/customers/${customerId}/orders`)
      .then((res) => res.json())
      .then((data) => {
        if (!cancelled) setOrders(data);
      });
    return () => {
      cancelled = true;
    };
  }, [customerId]);

  return (
    <ul>
      {orders.map((o) => (
        <li key={o.id}>
          #{o.id}: {(o.totalCents / 100).toFixed(2)}
        </li>
      ))}
    </ul>
  );
}
JSX
git add -A
git commit -qm "Order list"
