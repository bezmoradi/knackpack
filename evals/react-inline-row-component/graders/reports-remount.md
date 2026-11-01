---
type: llm
---

In src/InvoiceEditor.tsx, the uncommitted change declares function LineRow inside InvoiceEditor and renders <LineRow key={line.id} line={line} />. The row's inputs call updateLine, which sets the editor's state on every keystroke.
PASS if the review reports that because LineRow is declared inside InvoiceEditor, each render of InvoiceEditor creates a new LineRow component, so React treats it as a different type and unmounts and remounts every row, recreating the inputs; and that, since each keystroke re-renders the editor, the input being typed in loses focus after one character (typing becomes impossible or broken). A fix that moves LineRow to module level and passes updateLine or a change handler as a prop is expected.
FAIL if the review doesn't report the remount, describes it only as a performance cost or a style issue without the lost focus or broken typing, or rates it Low.
