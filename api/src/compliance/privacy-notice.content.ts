/**
 * Default Notice of Privacy Practices and Privacy Policy templates.
 * ATTORNEY REVIEW REQUIRED — replace bracketed placeholders before production.
 */

export const PRIVACY_PLACEHOLDERS = {
  companyLegalName: '[Company Legal Name]',
  appName: '[App Name]',
  privacyOfficerName: '[Privacy Officer Name]',
  privacyOfficerEmail: '[Privacy Officer Email]',
  privacyOfficerPhone: '[Privacy Officer Phone]',
  companyAddress: '[Company Address]',
  effectiveDate: '[Effective Date]',
  state: '[State]',
  entityStatus: '[Covered Entity or Business Associate Status]',
} as const;

export const ACKNOWLEDGMENT_SHORT_TEXT = `By using this app, you understand that we may collect, use, store, and share your protected health information (PHI) only as described in our Notice of Privacy Practices and Privacy Policy. We may use this information for treatment, payment, healthcare operations, care coordination, appointment scheduling, secure messaging, billing, prescription delivery, and other permitted or required healthcare purposes.

You have rights regarding your health information, including the right to request access, correction, restriction, confidential communication, and a copy of the Notice of Privacy Practices.

By continuing, you acknowledge that you have received and can access our Notice of Privacy Practices.`;

export const ACKNOWLEDGMENT_CHECKBOX_TEXT =
  'I acknowledge receipt of the Notice of Privacy Practices.';

export function buildDefaultNoticeOfPrivacyPractices(): string {
  const p = PRIVACY_PLACEHOLDERS;
  return `# Notice of Privacy Practices

**Notice Version:** 1.0
**Effective Date:** ${p.effectiveDate}

This notice describes how medical information about you may be used and disclosed and how you can get access to this information. **Please review it carefully.**

## Our Duties
${p.companyLegalName} ("${p.appName}") is committed to protecting the privacy of your protected health information (PHI). We are required by law to maintain the privacy of PHI, provide you this Notice of Privacy Practices, and follow the terms of this notice. We will notify you of material changes as required by law.

**Entity status:** ${p.entityStatus}

## What Health Information We Collect
We may collect PHI including: name, date of birth, contact information, address, insurance information, medical history, diagnosis, therapy notes, prescriptions, appointment records, secure messages, uploaded files, billing/payment records, delivery information, and provider notes.

## How We May Use and Share Your Health Information
We may use and disclose PHI for the following purposes without your written authorization, when permitted or required by law:

### Treatment
Coordinating and providing healthcare services, including therapy, prescriptions, and care plans.

### Payment
Billing, claims, collections, and eligibility verification.

### Healthcare Operations
Quality improvement, training, compliance, and business management.

### Care Coordination
Sharing information with other providers involved in your care.

### Appointment Scheduling
Managing visits, reminders, and telehealth sessions.

### Prescription or Therapy Services
Documenting and delivering clinical services.

### Secure Messaging
Communicating about your care through encrypted in-app messaging.

### Billing and Insurance
Processing payments and insurance claims.

### Delivery or Location-Based Services
When applicable, confirming deliveries or service locations without exposing PHI in notifications.

### Business Associates and Service Providers
We may share PHI with vendors who perform services for us under Business Associate Agreements (BAAs), including hosting, payment processing, and secure messaging infrastructure.

## Uses That May Require Your Written Authorization
Marketing, sale of PHI, psychotherapy notes (where applicable), and other uses not described in this notice require your written authorization. You may revoke authorization in writing.

## Your Rights
- **Right to Access Your Records** — Request copies of your PHI.
- **Right to Request Corrections** — Request amendment of inaccurate PHI.
- **Right to Request Restrictions** — Ask us to limit uses or disclosures.
- **Right to Request Confidential Communications** — Request alternate contact methods.
- **Right to Request an Accounting of Disclosures** — Request a list of certain disclosures.
- **Right to Receive a Paper or Electronic Copy of This Notice** — Available in the app at any time.

## Breach Notification
We will notify you as required by law if a breach of unsecured PHI affects your information.

## Complaints
You may file a complaint with us or with the U.S. Department of Health and Human Services. We will not retaliate against you for filing a complaint.

## Contact Privacy Officer
**${p.privacyOfficerName}**
Email: ${p.privacyOfficerEmail}
Phone: ${p.privacyOfficerPhone}
Address: ${p.companyAddress}

## Changes to This Notice
We reserve the right to change this notice. The current version will be published in the app. Material changes may require renewed acknowledgment.

---
*This document is a technical template for compliance review and does not constitute legal advice.*`;
}

export function buildDefaultPrivacyPolicy(): string {
  const p = PRIVACY_PLACEHOLDERS;
  return `# Privacy Policy

**Effective Date:** ${p.effectiveDate}
**App:** ${p.appName}
**Operator:** ${p.companyLegalName}

## Information We Collect

### Account Information
Name, email, phone, password (hashed), and role.

### Health Information
PHI as described in our Notice of Privacy Practices.

### Device Information
Device model, OS version, app version, and a stable device identifier for security and fraud prevention.

### Location Data
When you enable location features for appointments, deliveries, or EVV, we collect location only as needed for those features.

### Payment Information
Payments are processed by PCI-compliant third parties; we do not store full card numbers.

### Analytics
We do not send PHI to third-party analytics. Any operational analytics use de-identified or aggregated data only unless a BAA is in place.

## How We Protect Data
- Encryption in transit (HTTPS/TLS)
- Encryption at rest for sensitive fields and documents
- Role-based access control and audit logging
- Multi-factor authentication for workforce accounts
- Session timeout and automatic logout

## Data Retention
Clinical and billing records are retained per applicable law and our retention policy. Contact the Privacy Officer for details.

## Data Deletion Requests
Submit a request through Settings → Privacy & HIPAA. Some records must be retained by law.

## Children's Privacy
Services are intended for use by adults/guardians coordinating care for minors. We do not knowingly collect information from children without appropriate guardian involvement.

## Third-Party Service Providers
We use HIPAA-appropriate vendors under BAAs where PHI is involved.

## Contact Us
${p.privacyOfficerEmail} | ${p.privacyOfficerPhone}

---
*Attorney review required before production use.*`;
}
