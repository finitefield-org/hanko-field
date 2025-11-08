# API Post-Launch Monitoring & Improvement Checklist

This document defines the monitoring assets, KPIs, feedback loops, and iteration cadence for the Hanko Field API (Go service on Cloud Run backed by Firestore, Firebase Auth, and Firebase Storage). Share it with on-call engineers, product, and support before launch.

## Observability Assets & Owners
- **Cloud Run service dashboard** (`console.cloud.google.com/run/detail/...`): latency percentiles (p50/p95/p99), request volume, 4xx/5xx split, autoscaling events. _Owner: API platform_.
- **Cloud Monitoring custom SLI/SLO dashboard**: availability (>=99.5%), error budget burn, CPU/memory, startup latency. _Owner: SRE_.
- **Cloud Trace / Cloud Logging explorer views**: trace sampling, top slow endpoints, panic stack traces with correlation IDs. _Owner: API platform_.
- **Firestore metrics dashboard**: document read/write throttling, latency, index utilization. _Owner: Data platform_.
- **Firebase Auth insights**: sign-in failure rate, suspicious activity detection. _Owner: Security_.
- **Incident response board** (PagerDuty/Slack `#api-alerts`): alerts routed to on-call, track acknowledgement/resolve SLA.
- **Support desk board** (Help Scout/Jira Service Management): categorized tickets for post-launch regression detection.

Cadence: Dashboards 1–4 reviewed twice daily during first two weeks post-launch, then daily. Alerts remain 24/7.

## KPIs & Thresholds
| KPI | Target / Threshold | Signal Source |
| --- | --- | --- |
| Availability (successful responses ÷ total) | ≥ 99.5% per day, alert at 99.2% | Cloud Monitoring SLO |
| P95 latency per endpoint | < 450 ms for read, < 650 ms for write; alert if 20% regression vs baseline | Cloud Run dashboard + Trace |
| Error rate (5xx) | < 0.5% sustained 5 min window | Cloud Monitoring |
| Auth failure rate | < 2% of total sign-ins | Firebase Auth insights |
| Firestore contention / retries | < 3% of writes; alert at 5% | Firestore metrics |
| Order creation success | ≥ 97% of initiated checkouts | Business telemetry (BigQuery export) |
| Support ticket backlog | < 10 open Sev3+, < 3 open Sev2+ | Support board |

## Feedback Loops
- **In-app telemetry**: capture API error codes surfaced to app/web clients; feed to Looker Studio for daily review.
- **Support & CS tickets**: tag issues by feature, severity, root cause candidate; summarize in weekly quality report.
- **Sales / CSM notes**: maintain shared doc summarizing merchant feedback; convert into backlog items.
- **User surveys / NPS**: trigger 2 weeks and 6 weeks post-launch; share verbatim responses with product + API squads.
- **Release outcome survey for engineers**: collect lessons learned on deployment, tooling, and docs; integrate into retro.

## Review & Iteration Cadence
- **Daily launch standup (first 14 days)**: on-call, product, support. Review overnight alerts, KPIs, incoming feedback, and mitigation progress.
- **Weekly post-launch quality review**: inspect KPI deltas, backlog aging, error budget burn, and upcoming experiments. Update roadmap priorities.
- **Bi-weekly backlog grooming**: triage new insights, size enhancements, and replenish next two sprint candidates.
- **30-day and 90-day retrospectives**: evaluate adoption KPIs, process gaps, infra costs, and decide on structural improvements.

## Bug Triage & Escalation
1. **Intake**: Alerts (PagerDuty), support tickets, or QA reports create Jira issues with environment, request ID, and reproduction steps.
2. **Severity classification**:
   - **Sev1**: complete outage, data loss, security breach → page primary on-call, engage incident commander, 1-hour resolution target.
   - **Sev2**: major feature unusable or repeated failures affecting >10% of users → notify `#api-alerts`, fix within 1 business day.
   - **Sev3**: degraded experience or bug with workaround → assign during next sprint, track in quality backlog.
   - **Sev4**: polish / low impact → backlog for grooming.
3. **Escalation path**:
   - Primary on-call → secondary engineer → API lead → Director of Engineering.
   - Security/privacy implications escalate immediately to Security lead and DPO.
   - Customer-impacting Sev1/Sev2 require comms template sent within 30 minutes (status page + CSM brief).
4. **Bug review**: maintain dashboard of open issues by severity and age; review during weekly quality meeting.

## Backlog & Continuous Improvement Workflow
- Capture every Sev2+ root cause and feedback theme as a tracked remediation item with owner and due date.
- Add instrumentation debt, alert tuning, and documentation updates to the same backlog to avoid regressions.
- During grooming, score items on user impact, effort, and risk; roll into next sprint once acceptance criteria and validation steps are defined.
- Close the loop by posting resolution notes (fix version, test evidence, monitoring updates) to `#launch-readiness`.

## References
- `doc/api/operations` for runbooks and incident templates.
- `doc/api/testing-matrix.md` for regression coverage expectations.
- `doc/api/security` for disclosure and response policies.
