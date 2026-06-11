# HIPAA-Eligible Hosting Architecture

BloomOra is designed to deploy on HIPAA-eligible cloud infrastructure. **Final HIPAA compliance** still requires signed BAAs, organizational policies, risk analysis, workforce training, and legal review.

## Recommended platforms

| Provider | HIPAA program | Typical use |
|----------|---------------|-------------|
| AWS | HIPAA-eligible services + BAA | API, RDS, S3, KMS, CloudWatch |
| Google Cloud | HIPAA BAA available | GKE, Cloud SQL, Cloud Storage |
| Azure | HIPAA/HITRUST offerings | App Service, PostgreSQL, Key Vault |
| Aptible | HIPAA-focused PaaS | Managed containers + databases |

## Environment separation

| Environment | PHI policy | Database | Secrets |
|-------------|------------|----------|---------|
| **Development** | Synthetic data only; no production PHI | Local Docker Postgres | `.env` (never committed) |
| **Staging** | De-identified or synthetic; BAA-covered if real PHI used | Isolated RDS instance | AWS Secrets Manager / Parameter Store |
| **Production** | Live PHI | Private RDS in VPC; encryption at rest | Secrets Manager; rotate quarterly |

## Production checklist

- [ ] TLS 1.2+ terminated at load balancer (ACM / managed cert)
- [ ] Private subnets for API and database; no public DB access
- [ ] RDS / Cloud SQL encryption at rest enabled
- [ ] S3 bucket with SSE-KMS (`AWS_KMS_KEY_ID` in API env)
- [ ] Automated daily backups + tested restore procedure
- [ ] CloudTrail / audit logs for infrastructure changes
- [ ] GuardDuty or equivalent intrusion detection
- [ ] Error monitoring (Sentry/Datadog) without PHI in payloads
- [ ] Failed-login and unusual-access alerts to security channel
- [ ] `PHI_ENCRYPTION_KEY`, JWT secrets in secret manager only
- [ ] CORS locked to production app origins
- [ ] `npx prisma migrate deploy` in CI/CD before traffic shift

## Backup and restore

1. **Database:** automated snapshots (7–35 day retention) + weekly cross-region copy
2. **Documents (S3):** versioning + lifecycle to Glacier after retention period
3. **Restore drill:** quarterly restore to staging and verify API health + sample record integrity

## Monitoring alerts

Configure alerts for:

- API 5xx rate spike
- Failed login burst (`SecurityEvent` type `LOGIN_FAILED`)
- New-device logins from unusual geographies
- Backup job failures
- Certificate expiry (< 14 days)

## What not to do

- Do not store production PHI in developer laptops or unencrypted buckets
- Do not embed API keys or `PHI_ENCRYPTION_KEY` in mobile/web builds
- Do not use non-BAA email/SMS vendors for message content containing PHI

See also: [README.md](./README.md) for in-app technical safeguards.
