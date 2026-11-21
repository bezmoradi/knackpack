#!/bin/bash
# The rota shift-scheduling service from plan-brief-blocked-stops, with a
# requirements brief at docs/REQUIREMENTS.md written before the
# knackpack-requirements/1 format: no marker line and no Blocking: markers.
# requirements-check.sh prints "none", so the plan goes ahead as before and
# the reply says the brief wasn't checked. Nothing in the brief is left for
# the user to decide.
set -euo pipefail
export GIT_AUTHOR_DATE="2026-11-16T09:00:00Z" GIT_COMMITTER_DATE="2026-11-16T09:00:00Z"
git init -q -b main
git config user.name "Tomasz Wilk"
git config user.email "tomasz@example.com"
mkdir -p rota tests docs

cat > README.md <<'EOF'
# rota

Shift scheduling for small teams. Managers create shifts and assign them;
workers see their own upcoming shifts. `rota/` holds the service and `tests/`
its tests.

Run the tests with `python3 -m unittest`.
EOF

: > rota/__init__.py
: > tests/__init__.py

cat > rota/models.py <<'EOF'
"""Workers and shifts. All times are timezone-aware datetimes in UTC."""

from dataclasses import dataclass
from datetime import datetime
from typing import Optional


@dataclass
class Worker:
    id: int
    name: str
    team_id: int
    is_manager: bool = False


@dataclass
class Shift:
    id: int
    team_id: int
    starts_at: datetime
    ends_at: datetime
    worker_id: Optional[int] = None
EOF

cat > rota/store.py <<'EOF'
"""In-memory storage, one Store per process. The service is small enough
that a restart reloading from the nightly export is acceptable."""


class Store:
    def __init__(self):
        self.workers = {}
        self.shifts = {}

    def add_worker(self, worker):
        self.workers[worker.id] = worker

    def add_shift(self, shift):
        self.shifts[shift.id] = shift

    def shifts_of(self, worker_id):
        return [s for s in self.shifts.values() if s.worker_id == worker_id]
EOF

cat > rota/shifts.py <<'EOF'
"""Assigning shifts and listing them."""


class Forbidden(Exception):
    pass


class Conflict(Exception):
    pass


def overlaps(a, b):
    return a.starts_at < b.ends_at and b.starts_at < a.ends_at


def assign(store, actor, shift_id, worker_id):
    """A manager assigns one of their team's shifts to one of their team's
    workers. A worker is never on two overlapping shifts."""
    shift = store.shifts[shift_id]
    worker = store.workers[worker_id]
    if not actor.is_manager or actor.team_id != shift.team_id:
        raise Forbidden("only the team's manager assigns its shifts")
    if worker.team_id != shift.team_id:
        raise Forbidden("the worker isn't on this shift's team")
    for other in store.shifts_of(worker_id):
        if other.id != shift.id and overlaps(other, shift):
            raise Conflict(f"overlaps shift {other.id}")
    shift.worker_id = worker_id
    return shift


def upcoming(store, worker_id, now):
    """The worker's shifts that haven't started, earliest first."""
    return sorted(
        (s for s in store.shifts_of(worker_id) if s.starts_at > now),
        key=lambda s: s.starts_at,
    )
EOF

cat > rota/api.py <<'EOF'
"""HTTP handlers. Each takes the store, the signed-in worker and the request's
parameters, and returns (status, body)."""

from datetime import datetime, timezone

from rota import shifts


def _shift_json(s):
    return {
        "id": s.id,
        "starts_at": s.starts_at.isoformat(),
        "ends_at": s.ends_at.isoformat(),
        "worker_id": s.worker_id,
    }


def post_assignment(store, actor, shift_id, worker_id):
    try:
        shift = shifts.assign(store, actor, shift_id, worker_id)
    except shifts.Forbidden as e:
        return 403, {"error": str(e)}
    except shifts.Conflict as e:
        return 409, {"error": str(e)}
    return 200, _shift_json(shift)


def get_my_shifts(store, actor):
    now = datetime.now(timezone.utc)
    return 200, [_shift_json(s) for s in shifts.upcoming(store, actor.id, now)]
EOF

cat > tests/test_shifts.py <<'EOF'
import unittest
from datetime import datetime, timedelta, timezone

from rota import shifts
from rota.models import Shift, Worker
from rota.store import Store

T0 = datetime(2026, 11, 21, 6, 0, tzinfo=timezone.utc)


class AssignTest(unittest.TestCase):
    def setUp(self):
        self.store = Store()
        self.manager = Worker(1, "Mia", team_id=10, is_manager=True)
        self.ana = Worker(2, "Ana", team_id=10)
        for w in (self.manager, self.ana):
            self.store.add_worker(w)
        self.store.add_shift(Shift(100, 10, T0, T0 + timedelta(hours=8)))
        self.store.add_shift(Shift(101, 10, T0 + timedelta(hours=4), T0 + timedelta(hours=12)))

    def test_manager_assigns(self):
        shifts.assign(self.store, self.manager, 100, self.ana.id)
        self.assertEqual(self.store.shifts[100].worker_id, self.ana.id)

    def test_overlap_refused(self):
        shifts.assign(self.store, self.manager, 100, self.ana.id)
        with self.assertRaises(shifts.Conflict):
            shifts.assign(self.store, self.manager, 101, self.ana.id)

    def test_worker_cannot_assign(self):
        with self.assertRaises(shifts.Forbidden):
            shifts.assign(self.store, self.ana, 100, self.ana.id)


if __name__ == "__main__":
    unittest.main()
EOF

git add -A
git commit -qm "Shift scheduling: managers assign shifts, workers list theirs"

cat > docs/REQUIREMENTS.md <<'EOF'
# Weekly hours

### Readiness
- READY WITH ASSUMPTIONS: the remaining choices are explicit and nonblocking.

### Problem and outcome
Managers find out someone is over their contracted hours only when payroll
flags it at the end of the month. They want to see each worker's scheduled
hours for a week, and to see at a glance who is over 40.

### Scope
In scope: scheduled hours per worker per ISO week, for the worker
themselves and for their team's manager. Out of scope: hours actually worked
(there is no clock-in yet), per-contract thresholds, and payroll exports.

### Requirements and acceptance criteria
- REQ-01: A worker can see their own scheduled hours for a given ISO week.
  Verified by: Ana, with two 8-hour shifts in 2026-W48, asks for 2026-W48
  and gets 16.0; a week with no shifts gives 0.0.
- REQ-02: A shift that crosses midnight between two weeks counts toward the
  week it starts in. Verified by: a shift from Sunday 22:00 to Monday 06:00
  UTC adds 8.0 to the week of the Sunday and nothing to the next.
- REQ-03: A team's manager can see every worker on their team for a week,
  each with their hours and a flag when the total is over 40. Verified by: a
  worker with 42 hours is flagged, one with exactly 40 isn't, and a manager
  of another team, or a worker who isn't a manager, gets a 403.

### Constraints and dependencies
- Weeks are ISO weeks in UTC; the service stores every time in UTC already.
- The managers' assignment endpoint and the workers' shift list stay as
  they are.

### Decisions and assumptions
- Unassigned shifts count for nobody.
- The 40-hour line is fixed for now; per-contract thresholds come later.

### Open questions and risks
- Per-contract thresholds will need a contract record that doesn't exist
  yet; that's a later piece of work, not this one.
- Teams in other time zones may later want weeks in local time.

### Handoff
The adversarial reviewer can check REQ-01 to REQ-03 after implementation.
EOF
