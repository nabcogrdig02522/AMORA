# AMORA Release Risk Register

| Risk | Severity | Current position | Required mitigation / owner |
|---|---|---|---|
| Missing original base schema / migration drift | Critical | Prior sprint bundle assumes tables/columns not fully archived | Reconstruct canonical schema; DBA review and clean staging replay |
| Client/server preference mismatch | High | Some filters not yet enforced in regional discovery RPC | Enforce age, gender, goal, distance and country rules server-side |
| Payment webhook replay/concurrency | Critical | Verification exists; transactional concurrency needs testing | Add idempotency lock/transactional RPC; provider test suite |
| Non-Ghana payment coverage | High | Disabled; only Ghana Paystack configured | Integrate and certify each provider/currency separately |
| Underage access | Critical | 18+ policy exists; robust age assurance incomplete | Legal-approved age assurance and incident response |
| Identity/selfie assurance | High | Manual queue only; no liveness or ID vendor | Choose vendor/process, privacy impact assessment, retention policy |
| Member safety / moderation capacity | Critical | Reporting and admin workflows scaffolded | Staff moderation rota, SLAs, escalation and appeals |
| Account deletion and data rights | High | Request workflow only; manual processing needed | Verified deletion/export workflow and retention exceptions |
| Admin account compromise | Critical | app_metadata role and RLS model | MFA, least privilege, audit alerts, break-glass controls |
| App-store rejection | Medium | Store assets and legal disclosures not completed | Complete platform review checklist |
| Operational outage/data loss | Critical | No production SLO/restore evidence | Monitoring, backup, restore drills and incident runbook |
