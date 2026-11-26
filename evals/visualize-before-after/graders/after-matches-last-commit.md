---
type: llm
---

The user asked for a before-and-after of checkout.Total (checkout/total.go) across the last commit. Before, in the first commit: total = subtotal + shipping; if a code is given, it is looked up and its percent is taken off that total, shipping included, with no cap and no expiry check; then tax at the country's rate is added on the discounted total, shipping included. After, in the last commit: Total takes a now argument; if a code is given, it is looked up, an expired code returns ErrCodeExpired, the percent is capped at maxPercent (50) and taken off the items subtotal only; tax is computed on the discounted items only; shipping is added at the end, neither discounted nor taxed. This is Claude's final reply.
PASS if what the reply shows as after matches the last commit: an expired code rejected, the percent capped at 50, the discount taken off the items subtotal only, tax on the discounted items only, and shipping added last without discount or tax.
FAIL if the after leaves out the expiry check or the cap, discounts or taxes shipping, or gets the order of steps wrong, or if the reply shows no after. Count anything the reply doesn't show as a FAIL.
