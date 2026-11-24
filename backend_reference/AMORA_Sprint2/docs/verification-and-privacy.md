# Verification and privacy design

## Phone verification
Use Supabase Auth phone OTP with a contracted SMS provider. Verify phone ownership, not legal identity. Store normalized E.164 number and `phone_confirmed_at` through Auth. Do not publish phone number in discovery.

## Selfie verification
Selfie capture is a separate, consent-based step. A selfie photo review is not biometric liveness. If liveness is required, use a specialist vendor with documented liveness controls, spoof resistance, data processing terms and deletion guarantees.

## Optional identity verification
Do not build an in-house Ghana Card OCR / face-match system in the MVP. Contract a reputable verification provider after legal, security and vendor due diligence. Obtain explicit consent, disclose purpose and retention, and store provider outcome/reference only where possible. Avoid retaining raw ID images unless strictly necessary.

## Reviewer access
Use a separate admin role assigned in trusted `app_metadata`. Limit reviewer access to named staff, log every decision, require MFA for staff, and issue short-lived signed URLs. Do not use public buckets.

## Data minimisation
Do not use religion, ethnicity, political opinions, health data, sexual-life information or other sensitive attributes to score compatibility. Let members choose visible profile content. Allow correction, export and deletion requests.
