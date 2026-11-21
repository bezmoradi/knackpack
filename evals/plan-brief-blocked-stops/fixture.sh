#!/bin/bash
# A small shift-scheduling service, rota, with a requirements brief in the
# knackpack-requirements/1 format at docs/REQUIREMENTS.md for letting staff
# swap shifts. Its question Q-02, whether a swap takes effect when the
# colleague accepts or only once a manager approves it, says Blocking: yes,
# so requirements-check.sh prints "blocked Q-02" and planning has to stop
# and ask.
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
knackpack-requirements/1

# Shift swaps

### Readiness
- BLOCKED ON DECISIONS: Q-02 decides when a swap takes effect.

### Problem and outcome
Workers trade shifts today by messaging their manager, who reassigns them by
hand, often days later. Workers should be able to hand a shift to a
teammate themselves, and the rota should show who is really working.

### Scope
In scope: offering one of your own upcoming shifts to a teammate, and the
teammate accepting or declining. Out of scope: open offers to the whole
team, swapping across teams, and notifications beyond the existing weekly
rota email.

### Requirements and acceptance criteria

#### REQ-01: A worker can offer one of their own upcoming shifts to a teammate
Acceptance: Given Ana assigned to a shift that hasn't started, when she offers it to Ben on her team, a pending offer is recorded and the shift stays Ana's. Offering a shift that isn't hers, one that has started, or to someone on another team answers 403 or 409 and records nothing.

#### REQ-02: The teammate can accept or decline an offer made to them
Acceptance: Only the worker the offer names can accept or decline it; anyone else gets a 403. A declined offer leaves the shift with Ana and can't be accepted afterwards.

#### REQ-03: A swap never puts a worker on two overlapping shifts
Acceptance: When Ben already has a shift overlapping the offered one, accepting answers 409 and the shift stays Ana's, the same rule managers' assignments follow today.

### Constraints and dependencies
- The store is in memory; an offer needs to survive no more than a shift does.
- Managers' existing assignment endpoint keeps working unchanged.

### Decisions and assumptions
- An offer that is neither accepted nor declined lapses when the shift starts.

### Open questions and risks
- Q-01: Should the weekly rota email list the swaps made that week? Blocking: no
- Q-02: Does a swap take effect as soon as the teammate accepts, or only once the team's manager approves it? Blocking: yes
- Risk: two workers accepting offers for overlapping shifts at the same moment could both pass the overlap check.

### Handoff
The adversarial reviewer can check REQ-01 to REQ-03 after implementation.
EOF
