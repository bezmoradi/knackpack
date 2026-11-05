---
type: llm
---

The uncommitted `src/reschedule.ts` declares `RescheduleRequest.days` as a `string` (filled from the "Move by" select in `src/main.ts`) and calls `shiftAppointment(appt, request.days)`, whose `days` parameter is a `number`. tsc reports TS2345 at that call. Because nothing type-checks after the change, the code ships, and in `shiftAppointment` the expression `start.getDate() + days` concatenates: for an appointment on the 12th, "Tomorrow" (`"1"`) gives `setDate("121")`, which moves it to the end of July instead of the 13th of April, and "In two weeks" moves it more than three years ahead.
PASS if the review reports that a string reaches `shiftAppointment`'s numeric `days` (the type error in `applyReschedule`, or the select value passed through unconverted), states that appointments are moved to wrong dates (string concatenation in `getDate() + days`, or an equivalent concrete wrong result), and grades it High or Critical.
FAIL if the review misses the string-to-number mismatch, reports it only as a type error without saying what happens at run time, claims the value is coerced to the right number, or grades it Medium or lower.
