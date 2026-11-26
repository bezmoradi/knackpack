---
type: llm
---

The user asked to compare two dashboard layouts, classic (src/layouts/classic.ts) and focus (src/layouts/focus.ts), on phone, tablet and desktop. Classic: on phone, header, alerts, kpis, chart and activity stacked, with nav in a bottom bar; on tablet the same panels stacked full width with nav in the header menu; on desktop a 240px nav sidebar down the left, then header, alerts, kpis, and chart with activity beside it. Focus: on every breakpoint nav is in the header menu, alerts behind the header bell and activity in a drawer; on phone and tablet header, chart, then kpis; on desktop the header, then the chart with kpis in a narrow column beside it. This is Claude's final reply.
PASS if the reply itself contains the comparison, as a table, a grid sketch, a diagram or a structured list, covering both layouts at all three breakpoints.
FAIL if the reply only points to a file or page instead of showing the comparison, or leaves out either layout or any of the three breakpoints. Count anything the reply doesn't show as a FAIL.
