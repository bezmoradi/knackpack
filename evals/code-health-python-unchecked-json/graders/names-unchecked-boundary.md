---
type: llm
---

billing/api.py's update_subscription runs payload = cast(SubscriptionUpdate, json.loads(body)) and then reads payload["plan"]["id"], compares payload["seats"] with an int and passes payload["extend_trial_days"] to timedelta. typing.cast checks nothing at run time, so a body without plan, with seats as a string or that isn't an object raises KeyError or TypeError instead of a 400. create_customer and cancel_subscription check every field, and update_subscription is the function that changes most often.
PASS if the report has a finding that names update_subscription, or the cast to SubscriptionUpdate in billing/api.py, as request JSON used as a typed structure without validation.
FAIL if no finding names that function or cast for it, for example if the report mentions the TypedDict only as a positive signal, or names unvalidated input only somewhere else.
