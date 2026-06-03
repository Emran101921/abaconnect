# HIPAA Compliance Documentation (ABAConnect)

## Organizational requirements (outside codebase)

- Designate **Privacy Officer** and **Security Officer**
- Complete annual **risk assessment** and remediation plan
- Workforce **HIPAA training** and sanction policy
- Signed **BAAs** with: AWS, Stripe, telehealth vendor, SMS/email providers, AI vendor (if PHI used)
- **Incident response** and breach notification procedures (60-day rule)
- **Business continuity** and disaster recovery tested annually

## Technical safeguards implemented in platform

| Safeguard | Implementation |
|-----------|----------------|
| Access control | JWT + RBAC (`UserRole`), tenant isolation |
| Audit controls | `AuditLog` model, document access logs |
| Integrity | Prisma transactions, versioned screening templates |
| Transmission security | TLS (ALB/CloudFront), helmet middleware |
| Encryption at rest | RDS/S3 KMS (Terraform), field-level hooks for PHI |
| Authentication | bcrypt passwords, MFA-ready fields on `User` |
| Session management | Short-lived JWT, `lastLoginAt`, device registry |
| Minimum necessary | Role-based API modules |

## Consent & legal artifacts

- `HipaaConsent` records with version and timestamp
- Agency `baaSignedAt` on `Agency` model
- Telehealth `recordingConsent` on `TelehealthSession`

## Data retention

Configure per-tenant retention in `ComplianceModule` (default: 7 years clinical, 6 years billing per CMS guidance—confirm with counsel).

## Breach notification workflow

1. Detect via monitoring / user report → ticket `Complaint` / security channel  
2. Contain (revoke tokens, disable accounts)  
3. Assess scope via `AuditLog` queries  
4. Legal review → notify affected users and HHS if required  

## Pre-production checklist

- [ ] Penetration test  
- [ ] BAA executed with all subprocessors  
- [ ] AWS HIPAA account configuration  
- [ ] Disable default credentials and rotate secrets  
- [ ] Enable CloudTrail, GuardDuty, VPC flow logs  
- [ ] Document encryption key rotation  
