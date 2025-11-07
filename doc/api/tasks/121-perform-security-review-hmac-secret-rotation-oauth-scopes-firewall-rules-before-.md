# Perform security review (HMAC secret rotation, OAuth scopes, firewall rules) before launch.

**Parent Section:** 11. Security & Compliance
**Task ID:** 121

## Goal
Conduct comprehensive security review before launch covering secrets, OAuth scopes, firewall rules, and threat modeling.

## Plan
- Run dependency vulnerability scans (govulncheck, Snyk) and patch findings.
- Review firewall/IP restrictions, Cloud Armor rules, and IAP configuration.
- Validate secret rotation process, key management, and audit trails.
- Perform threat modeling session; capture mitigations in security documentation.

---

## Security Review Summary (2025-11-07)

- Captured the full review log, findings, and action tracker in `doc/api/security/security_review_2025-11-07.md`.
- Verified HMAC middleware + Secret Manager wiring (`api/cmd/api/main.go`, `api/internal/platform/config/config.go`) and defined per-carrier secret rotation plus replay detection alerts.
- Audited OAuth/OIDC scopes, RBAC, and Terraform service accounts; defined least-privilege changes plus time-bound custom claims workflow.
- Documented firewall/IAP gaps (Cloud Armor, HTTPS LB, VPC egress) and threat modeling outcomes covering webhook, scheduler, and staff scope abuse scenarios.

## Follow-ups
- [ ] Track the nine remediation items listed in the action tracker (Cloud Armor, IAM tightening, secret rotation automation) through the security review retro.
- [ ] Incorporate the new rotation/claim-expiry checks into release and on-call checklists before enabling production traffic.
