---
type: llm
---

The user asked to compare two dashboard layouts, classic (src/layouts/classic.ts) and focus (src/layouts/focus.ts), on phone, tablet and desktop. Classic: on phone, header, alerts, kpis, chart and activity stacked, with nav in a bottom bar; on tablet the same panels stacked full width with nav in the header menu; on desktop a 240px nav sidebar down the left, then header, alerts, kpis, and chart with activity beside it. Focus: on every breakpoint nav is in the header menu, alerts behind the header bell and activity in a drawer; on phone and tablet header, chart, then kpis; on desktop the header, then the chart with kpis in a narrow column beside it. This is Claude's final reply.
PASS if, for focus on desktop, the reply shows no sidebar, with nav in the header menu, alerts behind the header bell and activity in a drawer rather than on screen.
FAIL if the reply gives focus on desktop a sidebar, shows alerts as a banner or activity as a visible panel there, or doesn't show focus on desktop. Count anything the reply doesn't show as a FAIL.
