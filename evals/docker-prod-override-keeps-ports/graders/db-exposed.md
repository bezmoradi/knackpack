---
type: llm
---

The base compose.yaml publishes the db service, Postgres, as "5432:5432", on every host interface, and the uncommitted compose.prod.yaml sets only `restart: unless-stopped` for db, so the merged production configuration still publishes 5432 on all interfaces. docs/deploy.md says production is a single VM with a public IP, that ufw allows only ports 22 and 443, and that Postgres must not be reachable from the network. Docker writes its own firewall rules for published ports, which take effect before ufw's.
PASS if the review reports that in production Postgres's port 5432 is still published on every host interface (and so reachable from the network or the internet, whether or not it explains that Docker bypasses ufw), and rates that finding High or Critical, or calls it blocking or a must-fix before the deploy.
FAIL if the review doesn't report the production database exposure, or reports it only at Medium or Low without calling it blocking.
