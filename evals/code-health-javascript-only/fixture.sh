#!/bin/bash
# A room-booking API in plain JavaScript (CommonJS, Express, node:test) with
# eight months of history: no TypeScript, no JSDoc types, no Python or Go, and
# no node_modules. No recipe measures function length, nesting or branches in
# JavaScript, so per-function complexity can only be read, not measured.
# Each commit writes every file at its step: a line ending in "#@N" exists from
# step N on, and one ending in "#@N-M" from step N until step M.
set -euo pipefail
git init -q -b main
git config user.name "Noor Haddad"
git config user.email "noor@example.com"
now=$(date +%s)
mkdir -p src/routes src/services test

reveal() { # <step> <file>, the marked text on stdin
	awk -v k="$1" '
	match($0, / +\/\/@[0-9]+(-[0-9]+)?$/) {
		m = substr($0, RSTART); sub(/^ +\/\/@/, "", m); line = substr($0, 1, RSTART - 1)
		n = split(m, r, "-"); if (k + 0 >= r[1] + 0 && (n == 1 || k + 0 < r[2] + 0)) print line
		next
	}
	{ print }' > "$2"
}

put() { # <step> <first step> <text> <file>
	[ "$1" -ge "$2" ] || return 0
	printf '%s' "$3" | reveal "$1" "$4"
}

commit() { # <step> <days ago> <who> <message>
	local ts=$((now - $2 * 86400 - 3600 * ($2 % 7))) name email
	case $3 in
	noor) name="Noor Haddad" email=noor@example.com ;;
	ben) name="Ben Castillo" email=ben@example.com ;;
	ines) name="Ines Moreau" email=ines@example.com ;;
	esac
	put "$1" 1 "$PACKAGE" package.json
	put "$1" 1 "$APP" src/app.js
	put "$1" 1 "$DB" src/db.js
	put "$1" 1 "$ROOMS" src/routes/rooms.js
	put "$1" 1 "$BOOKINGS" src/routes/bookings.js
	put "$1" 1 "$AVAILABILITY" src/services/availability.js
	put "$1" 3 "$AVAILTEST" test/availability.test.js
	put "$1" 1 "$README" README.md
	put "$1" 1 "$GITIGNORE" .gitignore
	git add -A
	GIT_AUTHOR_NAME=$name GIT_AUTHOR_EMAIL=$email GIT_COMMITTER_NAME=$name GIT_COMMITTER_EMAIL=$email \
		GIT_AUTHOR_DATE="$ts +0000" GIT_COMMITTER_DATE="$ts +0000" git commit -qm "$4"
}

IFS= read -r -d '' PACKAGE <<'JSON' || true
{
  "name": "roombook",
  "version": "1.4.0",
  "private": true,
  "main": "src/app.js",
  "scripts": {
    "start": "node src/app.js",
    "test": "node --test test/"
  },
  "engines": {
    "node": ">=20"
  },
  "dependencies": {
    "better-sqlite3": "^11.3.0",
    "express": "^4.21.0"
  }
}
JSON

IFS= read -r -d '' APP <<'JS' || true
'use strict';

const express = require('express');
const db = require('./db');
const rooms = require('./routes/rooms');
const bookings = require('./routes/bookings');

const app = express();
app.use(express.json({ limit: '100kb' }));
app.use('/rooms', rooms(db.open(process.env.ROOMBOOK_DB || 'roombook.db')));  //@1-6
app.use('/bookings', bookings(db.open(process.env.ROOMBOOK_DB || 'roombook.db')));  //@1-6
const conn = db.open(process.env.ROOMBOOK_DB || 'roombook.db');  //@6
app.use('/rooms', rooms(conn));  //@6
app.use('/bookings', bookings(conn));  //@6

app.use((err, req, res, next) => {  //@9
  console.error(err);  //@9
  res.status(500).json({ error: 'internal_error' });  //@9
});  //@9

if (require.main === module) {
  const port = Number(process.env.PORT || 3000);
  app.listen(port, '127.0.0.1', () => console.log(`roombook listening on ${port}`));
}

module.exports = app;
JS

IFS= read -r -d '' DB <<'JS' || true
'use strict';

const Database = require('better-sqlite3');

const SCHEMA = `
CREATE TABLE IF NOT EXISTS rooms (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  capacity INTEGER NOT NULL,
  floor INTEGER NOT NULL,  //@4
  features TEXT NOT NULL DEFAULT '[]'
);
CREATE TABLE IF NOT EXISTS bookings (
  id INTEGER PRIMARY KEY,
  room_id INTEGER NOT NULL REFERENCES rooms (id),
  starts_at TEXT NOT NULL,
  ends_at TEXT NOT NULL,
  organiser TEXT NOT NULL  //@1-8
  organiser TEXT NOT NULL,  //@8
  cancelled INTEGER NOT NULL DEFAULT 0  //@8
);
CREATE INDEX IF NOT EXISTS bookings_room_time ON bookings (room_id, starts_at);  //@11
`;

function open(path) {
  const conn = new Database(path);
  conn.pragma('journal_mode = WAL');
  conn.exec(SCHEMA);
  return conn;
}

module.exports = { open };
JS

IFS= read -r -d '' ROOMS <<'JS' || true
'use strict';

const express = require('express');
const { findFreeRooms } = require('../services/availability');

module.exports = function rooms(conn) {
  const router = express.Router();

  router.get('/', (req, res) => {
    const all = conn.prepare('SELECT * FROM rooms ORDER BY name').all();
    res.json(all.map((r) => ({ ...r, features: JSON.parse(r.features) })));
  });

  router.get('/free', (req, res) => {
    const { from, to } = req.query;
    if (!from || !to || Number.isNaN(Date.parse(from)) || Number.isNaN(Date.parse(to))) {
      return res.status(400).json({ error: 'from and to must be ISO dates' });
    }
    const all = conn.prepare('SELECT * FROM rooms').all().map((r) => ({ ...r, features: JSON.parse(r.features) }));
    const booked = conn.prepare('SELECT * FROM bookings WHERE ends_at > ? AND starts_at < ?').all(from, to);  //@1-8
    const booked = conn.prepare('SELECT * FROM bookings WHERE cancelled = 0 AND ends_at > ? AND starts_at < ?').all(from, to);  //@8
    const request = {
      from,
      to,
      people: Number(req.query.people || 1),
      features: req.query.features ? String(req.query.features).split(',') : [],  //@5
      floor: req.query.floor === undefined ? undefined : Number(req.query.floor),  //@4
    };
    res.json(findFreeRooms(all, booked, request));
  });

  return router;
};
JS

IFS= read -r -d '' BOOKINGS <<'JS' || true
'use strict';

const express = require('express');
const { overlaps } = require('../services/availability');

const MAX_HOURS = 8;  //@7

module.exports = function bookings(conn) {
  const router = express.Router();

  router.post('/', (req, res) => {
    const { roomId, startsAt, endsAt, organiser } = req.body || {};
    if (!Number.isInteger(roomId) || typeof organiser !== 'string' || !organiser.trim()) {
      return res.status(400).json({ error: 'roomId and organiser are required' });
    }
    const start = Date.parse(startsAt);
    const end = Date.parse(endsAt);
    if (Number.isNaN(start) || Number.isNaN(end) || end <= start) {
      return res.status(400).json({ error: 'startsAt and endsAt must be ISO dates, end after start' });
    }
    if (end - start > MAX_HOURS * 3600 * 1000) {  //@7
      return res.status(400).json({ error: `bookings can be at most ${MAX_HOURS} hours` });  //@7
    }  //@7
    const insert = conn.transaction(() => {
      const existing = conn.prepare('SELECT * FROM bookings WHERE room_id = ?').all(roomId);  //@1-8
      const existing = conn.prepare('SELECT * FROM bookings WHERE room_id = ? AND cancelled = 0').all(roomId);  //@8
      if (existing.some((b) => overlaps(b, { starts_at: startsAt, ends_at: endsAt }))) {
        return null;
      }
      return conn
        .prepare('INSERT INTO bookings (room_id, starts_at, ends_at, organiser) VALUES (?, ?, ?, ?)')
        .run(roomId, new Date(start).toISOString(), new Date(end).toISOString(), organiser.trim()).lastInsertRowid;
    });
    const id = insert();
    if (id === null) {
      return res.status(409).json({ error: 'the room is already booked then' });
    }
    res.status(201).json({ id: Number(id) });
  });
  //@8
  router.delete('/:id', (req, res) => {  //@8
    const result = conn.prepare('UPDATE bookings SET cancelled = 1 WHERE id = ? AND cancelled = 0').run(Number(req.params.id));  //@8
    if (result.changes === 0) {  //@8
      return res.status(404).json({ error: 'no such booking' });  //@8
    }  //@8
    res.status(204).end();  //@8
  });  //@8

  return router;
};
JS

IFS= read -r -d '' AVAILABILITY <<'JS' || true
'use strict';

function overlaps(a, b) {
  return Date.parse(a.starts_at) < Date.parse(b.ends_at) && Date.parse(b.starts_at) < Date.parse(a.ends_at);
}

// Rooms that fit the request and have no booking in it, best fit first: the
// smallest room that seats everyone, then the one on the requested floor.
function findFreeRooms(rooms, bookings, request) {
  const free = [];
  for (const room of rooms) {
    if (room.capacity < request.people) {
      continue;
    }
    if (request.features && request.features.length) {  //@5
      let hasAll = true;  //@5
      for (const feature of request.features) {  //@5
        if (!room.features.includes(feature)) {  //@5
          if (feature === 'video' && room.features.includes('screen')) {  //@10
            continue;  //@10
          }  //@10
          hasAll = false;  //@5
          break;  //@5
        }  //@5
      }  //@5
      if (!hasAll) {  //@5
        continue;  //@5
      }  //@5
    }  //@5
    let clash = false;
    for (const booking of bookings) {
      if (booking.room_id === room.id && overlaps(booking, { starts_at: request.from, ends_at: request.to })) {
        clash = true;
        break;
      }
    }
    if (!clash) {
      free.push(room);
    }
  }
  return free;  //@1-2
  return free.sort((a, b) => {  //@2
    if (a.capacity !== b.capacity) {  //@2
      return a.capacity - b.capacity;  //@2
    }  //@2
    if (request.floor !== undefined) {  //@4
      const da = Math.abs(a.floor - request.floor);  //@4
      const db = Math.abs(b.floor - request.floor);  //@4
      if (da !== db) {  //@4
        return da - db;  //@4
      }  //@4
    }  //@4
    return a.name.localeCompare(b.name);  //@2
  });  //@2
}

module.exports = { findFreeRooms, overlaps };
JS

IFS= read -r -d '' AVAILTEST <<'JS' || true
'use strict';

const test = require('node:test');
const assert = require('node:assert');
const { findFreeRooms, overlaps } = require('../src/services/availability');

const rooms = [
  { id: 1, name: 'Fjord', capacity: 8, floor: 2, features: ['screen'] },
  { id: 2, name: 'Atlas', capacity: 4, floor: 1, features: [] },
  { id: 3, name: 'Birch', capacity: 12, floor: 3, features: ['screen', 'whiteboard'] },
];
const hour = { from: '2026-03-02T09:00:00Z', to: '2026-03-02T10:00:00Z' };

test('touching bookings do not overlap', () => {
  assert.equal(overlaps({ starts_at: '2026-03-02T09:00:00Z', ends_at: '2026-03-02T10:00:00Z' }, { starts_at: '2026-03-02T10:00:00Z', ends_at: '2026-03-02T11:00:00Z' }), false);
});

test('smallest room that seats everyone comes first', () => {
  const free = findFreeRooms(rooms, [], { ...hour, people: 3, features: [] });
  assert.deepEqual(free.map((r) => r.name), ['Atlas', 'Fjord', 'Birch']);
});

test('a booked room is left out', () => {
  const free = findFreeRooms(rooms, [{ room_id: 2, starts_at: '2026-03-02T09:30:00Z', ends_at: '2026-03-02T11:00:00Z' }], { ...hour, people: 1, features: [] });
  assert.deepEqual(free.map((r) => r.name), ['Fjord', 'Birch']);
});
  //@5
test('rooms without a requested feature are left out', () => {  //@5
  const free = findFreeRooms(rooms, [], { ...hour, people: 1, features: ['whiteboard'] });  //@5
  assert.deepEqual(free.map((r) => r.name), ['Birch']);  //@5
});  //@5
JS

IFS= read -r -d '' README <<'MD' || true
# roombook

Books meeting rooms.

    GET    /rooms
    GET    /rooms/free?from=...&to=...&people=4&features=screen,whiteboard&floor=2
    POST   /bookings  {"roomId": 1, "startsAt": "...", "endsAt": "...", "organiser": "..."}
    DELETE /bookings/:id  //@12

## Development

Node 20 or later:

    npm install
    npm test
MD

IFS= read -r -d '' GITIGNORE <<'TXT' || true
node_modules/
*.db
*.db-wal
*.db-shm
TXT

commit 1 245 noor "Book rooms and list free ones"
commit 2 236 noor "Return free rooms smallest first"
commit 3 221 ben "Tests for room availability"
commit 4 204 ben "Prefer rooms on the requested floor"
commit 5 188 ines "Filter free rooms by feature"
commit 6 170 ines "Open the database once"
commit 7 151 noor "Limit bookings to 8 hours"
commit 8 129 ben "Cancel bookings"
commit 9 102 ines "Answer 500 with JSON"
commit 10 74 noor "A room with a screen will do for video calls"
commit 11 41 ben "Index bookings by room and start time"
commit 12 9 ines "README: cancelling bookings"
