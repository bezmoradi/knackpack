---
type: llm
---

PASS if the review points out at least three of these naming problems in reservation/reservation.go: the package name repeated in ReservationService or NewReservationService; the `self` receiver; the `Get` prefix on GetQuantity; `Id` instead of `ID` in reservationId or itemId; the ALL_CAPS constant MAX_QUANTITY; the `I` prefix on IStockTaker; the error variable NotFound not being named ErrNotFound, or its capitalized message ending in a period.
FAIL if it points out fewer than three of them.
