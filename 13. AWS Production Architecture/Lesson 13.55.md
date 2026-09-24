# AWS Masterclass — Phase 3

# Lesson 54: Amazon Cognito Production Identity Architecture

## 1. Lesson objectives

By the end of this lesson, you will understand how to:

* Distinguish Cognito user pools from identity pools.
* Design authentication for web, mobile and machine applications.
* Use OAuth 2.0 and OpenID Connect correctly.
* Choose authorization-code, client-credentials and refresh-token grants.
* Use PKCE for browser and mobile applications.
* Understand ID, access and refresh tokens.
* Validate Cognito JSON Web Tokens securely.
* Configure managed login and custom authentication interfaces.
* Use passwords, passwordless OTPs, passkeys and MFA.
* Federate Google, Apple, SAML and OIDC identities.
* Implement groups, roles and custom OAuth scopes.
* Authorize machine-to-machine workloads.
* Exchange user identities for temporary AWS credentials.
* Customize authentication using Lambda triggers.
* Configure threat protection, AWS WAF and compromised-credential detection.
* Design multi-tenant identity models.
* Handle logout, token rotation and token revocation.
* Monitor authentication activity and investigate failures.
* Design multi-Region authentication resilience.
* Provision Cognito using Terraform.

---

# 2. What is Amazon Cognito?

Amazon Cognito is a managed identity service for application users.

It provides two major components:

```text
Amazon Cognito user pools
Amazon Cognito identity pools
```

A user pool authenticates users and issues tokens. An identity pool exchanges trusted identities for temporary AWS credentials. ([AWS Documentation][1])

Basic architecture:

```text
Application user
      |
      v
Cognito user pool
      |
      | ID, access and refresh tokens
      v
Application API
```

Optional AWS-resource access:

```text
Cognito user-pool token
          |
          v
Cognito identity pool
          |
          v
Temporary AWS credentials
          |
          v
S3 / DynamoDB / AppSync / other AWS APIs
```

---

# 3. User pool versus identity pool

## User pool

A user pool is an application user directory and authentication service.

It handles:

* User registration.
* Sign-in.
* Passwords.
* Passkeys.
* Email and SMS one-time passwords.
* MFA.
* Account recovery.
* Social and enterprise federation.
* OAuth 2.0.
* OpenID Connect.
* JWT issuance.
* Groups and claims.
* Managed login pages. ([AWS Documentation][2])

## Identity pool

An identity pool provides temporary AWS credentials to:

* Authenticated application users.
* Users authenticated by external identity providers.
* Optionally, unauthenticated guest users.

Those credentials assume IAM roles and authorize direct AWS API requests. ([AWS Documentation][3])

## Never-forget distinction

```text
User pool:
Who is the user?

Identity pool:
Which temporary AWS role may this identity assume?
```

---

# 4. Cognito is not IAM Identity Center

Do not confuse application-customer identity with workforce identity.

```text
Amazon Cognito:
Customers and application users

IAM Identity Center:
Employees and workforce access to AWS/accounts/apps

IAM users and roles:
AWS API authorization identities
```

Example:

```text
Customer signing in to TodoApp:
Cognito

DevOps engineer accessing AWS Console:
IAM Identity Center

ECS task accessing DynamoDB:
IAM task role
```

---

# 5. Production identity architecture

```text
Browser or mobile app
         |
         v
Cognito managed login
         |
         ├── Local Cognito user
         ├── Google
         ├── Apple
         ├── Enterprise OIDC
         └── Enterprise SAML
         |
         v
Authorization code
         |
         v
Code + PKCE exchange
         |
         v
ID token + access token + refresh token
         |
         v
API Gateway / AppSync / application API
         |
         v
Business authorization
```

The access token authorizes API operations. The ID token communicates identity information to the client. The refresh token maintains the user’s session by obtaining new access and ID tokens. ([AWS Documentation][4])

---

# 6. User-pool feature plans

Cognito user pools currently offer:

```text
Lite
Essentials
Plus
```

New user pools default to the Essentials plan. Plans have different authentication, customization, token and threat-protection capabilities. ([AWS Documentation][5])

## Lite

Suitable for fundamental user-directory and authentication requirements.

Examples include:

* Local users.
* Federation.
* Groups.
* OAuth/OIDC authorization server.
* Basic managed authentication capabilities.

## Essentials

Adds broader modern authentication capabilities such as:

* Managed-login branding.
* Choice-based authentication.
* Passkeys and passwordless configurations.
* Password history.
* More token customization options.

## Plus

Adds advanced threat-protection capabilities such as:

* Adaptive authentication.
* Risk-based MFA.
* Compromised-credential detection.
* Extended authentication-event analysis and logging. ([AWS Documentation][6])

Do not select a plan only by its name. Map required security controls and monthly active-user cost to each environment.

---

# 7. User-pool components

```text
User pool
├── Users
├── User attributes
├── Groups
├── App clients
├── Domain
├── Managed login
├── Identity providers
├── Resource servers
├── OAuth scopes
├── Lambda triggers
├── MFA configuration
├── Password/passkey configuration
├── Threat protection
└── Token settings
```

The user pool is the shared user directory.

The app client represents one application that authenticates against that directory.

---

# 8. App clients

Create a separate app client for each application type.

Example:

```text
TodoApp web SPA
TodoApp mobile app
TodoApp server-rendered website
TodoApp administration portal
TodoApp machine-to-machine worker
```

Each app client can have different:

* OAuth grant types.
* Callback URLs.
* Logout URLs.
* Allowed identity providers.
* Scopes.
* Token lifetimes.
* Authentication flows.
* Client secret.
* Refresh-token settings.
* Threat-protection settings. ([AWS Documentation][7])

Do not use one app client for every application and environment.

---

# 9. Public versus confidential clients

## Public client

A public client cannot securely protect a client secret.

Examples:

```text
Browser SPA
Mobile application
Desktop application
```

A user can inspect:

* JavaScript.
* Browser storage.
* Mobile application files.
* Network requests.

Therefore:

```text
Public client:
No client secret
Authorization code + PKCE
```

## Confidential client

A confidential client runs in a trusted backend and can protect a secret.

Examples:

```text
Server-rendered web backend
Internal application server
Machine-to-machine service
```

Therefore:

```text
Confidential client:
Client ID + client secret
```

Never embed a Cognito client secret inside browser JavaScript or a mobile application package.

---

# 10. User-pool domains

A domain enables:

* Managed-login pages.
* OAuth authorization endpoint.
* Token endpoint.
* Logout endpoint.
* UserInfo endpoint.
* Third-party identity-provider redirects.
* Client-credentials token requests. ([AWS Documentation][8])

Two domain choices exist:

```text
AWS-owned prefix domain
Custom domain
```

Example prefix domain:

```text
todoapp-production.auth.ap-south-1.amazoncognito.com
```

Example custom domain:

```text
auth.yourdatascientist.tech
```

---

# 11. Managed login

Managed login is Cognito’s managed web interface for:

* Sign-up.
* Sign-in.
* Password recovery.
* MFA setup.
* Passkey operations.
* Federation.
* Logout.
* Authentication-method selection.

Adding a domain also makes the user pool an OAuth 2.0 authorization server and OIDC identity provider. ([AWS Documentation][9])

Architecture:

```text
Application
    |
    | Redirect
    v
Cognito managed login
    |
    | Authenticate
    v
Application callback URL
```

Managed login reduces the amount of sensitive authentication code your application must implement.

---

# 12. Managed login versus custom UI

## Managed login

Advantages:

* AWS handles authentication pages.
* OAuth/OIDC flows are integrated.
* Federation redirects are managed.
* MFA and passkey flows are managed.
* Less password-handling code.
* Branding editor is available.

## Custom UI

Your application uses Cognito APIs through an AWS SDK.

Advantages:

* Complete user-experience control.
* Authentication embedded directly in your application.
* Custom challenge support.
* Application-specific step handling.

Risks:

* More security-sensitive code.
* More challenge-state handling.
* More browser/mobile token handling.
* More testing for MFA, password reset and passkeys.

AWS recommends passkeys and secure managed authentication approaches where they fit the application’s requirements. ([AWS Documentation][10])

---

# 13. Managed-login branding

The current managed-login experience includes a branding editor that can customize elements such as:

* Logos.
* Backgrounds.
* Typography.
* Colours.
* Buttons.
* Layout.
* App-client-specific style.

The branding editor is the newer managed-login customization option, while classic hosted-UI branding remains a separate older experience. ([AWS Documentation][11])

Branding improves trust, but the authentication hostname remains equally important.

---

# 14. Cognito custom-domain certificate Region

Cognito custom domains use CloudFront infrastructure.

Regardless of the user pool’s Region, the ACM certificate for a Cognito custom domain must be created in:

```text
us-east-1
```

For example:

```text
User pool:
ap-south-1

Custom-domain certificate:
us-east-1

Domain:
auth.yourdatascientist.tech
```

([AWS Documentation][12])

This differs from an API Gateway Regional custom domain, where the certificate belongs in the API’s Region.

---

# 15. Cognito custom-domain DNS

After creating the Cognito custom domain, Cognito returns an alias target.

```text
auth.yourdatascientist.tech
        |
        | DNS alias
        v
Cognito-provided CloudFront target
```

The parent domain must already resolve through DNS before Cognito accepts the custom domain. ([AWS Documentation][12])

Recommended hierarchy:

```text
yourdatascientist.tech
└── auth.yourdatascientist.tech
```

Do not place arbitrary reverse proxies in front of Cognito endpoints unless the design is explicitly supported and thoroughly tested.

---

# Part 1 — OAuth 2.0 and OpenID Connect

# 16. OAuth 2.0 versus OIDC

## OAuth 2.0

OAuth answers:

```text
What is this client allowed to access?
```

It primarily uses:

```text
Access tokens
Scopes
Resource servers
```

## OpenID Connect

OIDC builds identity authentication on top of OAuth 2.0.

It answers:

```text
Who authenticated?
```

It introduces:

```text
ID token
UserInfo endpoint
Standard identity claims
```

Cognito acts as both an OAuth 2.0 authorization server and OIDC identity provider. ([AWS Documentation][9])

---

# 17. OAuth roles

```text
Resource owner:
The user

Client:
Web or mobile application

Authorization server:
Cognito user pool

Resource server:
Your protected API
```

Flow:

```text
User
  |
  v
Client application
  |
  v
Cognito authorization server
  |
  | Access token
  v
Protected API
```

---

# 18. Authorization-code grant

The authorization-code grant is the recommended interactive browser-based flow.

```text
Browser
   |
   | /oauth2/authorize
   v
Cognito managed login
   |
   | User authenticates
   v
Redirect with short-lived code
   |
   v
Token endpoint
   |
   v
ID + access + refresh tokens
```

The code is exchanged at the token endpoint. Cognito recommends the code grant rather than implicit token delivery, and it is the interactive flow that returns a refresh token. ([AWS Documentation][13])

---

# 19. PKCE

PKCE means:

```text
Proof Key for Code Exchange
```

PKCE protects public clients from authorization-code interception.

Client generates:

```text
code_verifier:
High-entropy secret

code_challenge:
Derived from code_verifier
```

Authorization request sends:

```text
code_challenge
```

Token request sends:

```text
code_verifier
```

Cognito validates that they match before exchanging the code. ([AWS Documentation][14])

## Production rule

```text
Browser SPA:
Authorization code + PKCE

Mobile app:
Authorization code + PKCE
```

---

# 20. Authorization-code flow example

```text
1. Browser generates code_verifier.

2. Browser calculates code_challenge.

3. Browser redirects to Cognito /oauth2/authorize.

4. User authenticates.

5. Cognito redirects to application callback with code.

6. Application submits:
   code
   client_id
   redirect_uri
   code_verifier

7. Cognito returns tokens.
```

Callback URLs must exactly match the URLs configured on the app client.

---

# 21. The `state` parameter

Authorization requests should include a cryptographically random `state` value.

```text
Application stores:
state = random value

Cognito redirects:
?code=...&state=...

Application verifies:
returned state == stored state
```

This helps protect against cross-site request forgery and authorization-response confusion.

Never use a predictable state value such as:

```text
state=123
```

---

# 22. Nonce

OIDC clients can use a `nonce` value to associate an ID token with the authentication request that created it.

```text
Authorization request:
nonce=random-value

ID token:
nonce=random-value
```

The application validates the returned nonce.

This helps prevent replay or substitution of ID tokens in browser-based authentication flows.

---

# 23. Implicit grant

The implicit grant returns ID and access tokens directly through the browser redirect.

```text
Cognito
   |
   v
https://app.example.com/callback#access_token=...
```

AWS documents the implicit grant as a legacy flow and recommends authorization code instead because tokens are exposed more directly to the browser and URL-processing environment. ([AWS Documentation][15])

Production recommendation:

```text
Disable implicit grant
unless a legacy application genuinely requires it.
```

---

# 24. Client-credentials grant

The client-credentials grant supports machine-to-machine authorization.

```text
Backend service
      |
      | Client ID + secret
      v
Cognito token endpoint
      |
      | Access token
      v
Protected API
```

There is:

* No human user.
* No ID token.
* Normally no refresh token.
* No interactive login.

The app client must have a secret, a user-pool domain and permission for custom resource-server scopes. ([AWS Documentation][16])

---

# 25. M2M example

```text
Nightly reporting service
      |
      | client_credentials
      v
Cognito
      |
      | access token:
      | todo-api/reports.read
      v
Reporting API
```

Example request:

```bash
curl \
  --request POST \
  "https://auth.yourdatascientist.tech/oauth2/token" \
  --user "${COGNITO_CLIENT_ID}:${COGNITO_CLIENT_SECRET}" \
  --header "Content-Type: application/x-www-form-urlencoded" \
  --data "grant_type=client_credentials&scope=todo-api/reports.read"
```

Store the client secret in:

* Secrets Manager.
* A secure CI/CD secret store.
* ECS secret injection.
* Kubernetes secret management integrated with KMS.

Never commit it into Git.

---

# 26. Refresh-token grant

A refresh token obtains new access and ID tokens without requiring the user to enter credentials again.

```text
Access token expires
      |
      v
Application presents refresh token
      |
      v
Cognito issues new tokens
```

Cognito’s default refresh-token lifetime is 30 days, and app clients can configure it from 60 minutes through 10 years. ([AWS Documentation][17])

A long refresh-token lifetime improves user convenience but increases exposure if a token is stolen.

---

# 27. Refresh-token rotation

With refresh-token rotation:

```text
Old refresh token
      |
      v
Token refresh
      |
      ├── New access token
      ├── New ID token
      └── New refresh token
```

The application replaces the old refresh token after each refresh.

Cognito supports a grace period to tolerate limited concurrent use during token replacement. When rotation is active, applications use the supported refresh-token exchange operation rather than legacy refresh authentication behaviour. ([AWS Documentation][18])

Benefits:

* Reduces the reusable lifetime of a stolen refresh token.
* Helps detect replay.
* Limits persistent session compromise.

---

# Part 2 — Cognito tokens

# 28. Token types

```text
ID token
Access token
Refresh token
```

## ID token

Contains identity claims.

## Access token

Contains API authorization information.

## Refresh token

Obtains new ID and access tokens.

---

# 29. ID token

An ID token commonly contains claims such as:

```json
{
  "sub": "user-unique-identifier",
  "email": "user@example.com",
  "email_verified": true,
  "cognito:username": "user-104",
  "cognito:groups": [
    "TodoUsers"
  ],
  "token_use": "id",
  "iss": "https://cognito-idp.ap-south-1.amazonaws.com/ap-south-1_EXAMPLE",
  "aud": "app-client-id",
  "exp": 1785650000
}
```

Use the ID token for:

* Displaying the signed-in user.
* Reading permitted identity claims.
* Creating the client session.
* Personalising the user interface.

Cognito ID tokens can include standard OIDC claims, Cognito groups and preferred-role claims. ([AWS Documentation][19])

---

# 30. Access token

An access token commonly contains:

```json
{
  "sub": "user-unique-identifier",
  "client_id": "app-client-id",
  "scope": "openid todo-api/todos.read todo-api/todos.write",
  "cognito:groups": [
    "TodoUsers"
  ],
  "token_use": "access",
  "iss": "https://cognito-idp.ap-south-1.amazonaws.com/ap-south-1_EXAMPLE",
  "exp": 1785650000
}
```

Use the access token to authorize API calls.

```http
Authorization: Bearer <access-token>
```

Cognito access tokens carry scopes and other authorization claims and can include token-revocation identifiers. ([AWS Documentation][20])

---

# 31. Do not authorize APIs with the ID token

Bad:

```text
API receives ID token
      |
      v
Email claim exists
      |
      v
API allows write operation
```

Better:

```text
API receives access token
      |
      v
Validate token
      |
      v
Require:
todo-api/todos.write
```

The ID token proves authentication to the client. The access token represents the authorization issued for protected resources.

---

# 32. Refresh token

Refresh tokens are opaque session credentials.

Do not:

* Decode them as JWTs.
* Send them to normal APIs.
* Store them in application logs.
* Include them in URLs.
* Share them between applications.
* Store them in insecure browser-accessible storage.

They should be handled like sensitive credentials.

---

# 33. JWT structure

A JWT contains:

```text
Header.Payload.Signature
```

Example:

```text
eyJraWQiOi...
.
eyJzdWIiOi...
.
signature
```

## Header

```json
{
  "kid": "key-id",
  "alg": "RS256"
}
```

## Payload

Contains claims.

## Signature

Proves the token was issued by the trusted signing key and has not been modified.

---

# 34. JWT validation checklist

A protected API must verify:

```text
[ ] Signature is valid
[ ] Signing key comes from trusted Cognito JWKS
[ ] iss matches the expected user pool
[ ] token_use is access
[ ] Token has not expired
[ ] Client ID or audience is expected
[ ] Required scope is present
[ ] Required group or claim is present
[ ] Tenant access matches the requested resource
```

Cognito exposes OIDC discovery and JWKS endpoints for token validation. ([AWS Documentation][21])

Do not merely base64-decode a JWT and trust its claims.

---

# 35. Signing-key rotation

Cognito can rotate token-signing keys.

Your application should:

```text
1. Read the token header kid.

2. Look up the matching JWKS key.

3. Cache keys for a reasonable duration.

4. Refresh JWKS when an unknown kid appears.

5. Verify the signature.
```

Do not hard-code one public key permanently.

---

# 36. Token lifetimes

Cognito app clients can configure different validity durations for:

```text
Access tokens
ID tokens
Refresh tokens
Authentication sessions
```

([AWS Documentation][22])

Typical starting point:

```text
Access token:
15–60 minutes

ID token:
15–60 minutes

Refresh token:
Several days or weeks
```

Shorter access tokens reduce exposure but increase token-refresh traffic.

---

# 37. Managed-login cookie lifetime

Managed login sets a browser session cookie that is valid for one hour.

Configuring access or ID tokens shorter than one hour does not necessarily force the user to enter credentials again while that managed-login browser session remains valid. ([AWS Documentation][19])

Distinguish:

```text
API access-token lifetime
from
Cognito managed-login browser session
```

---

# 38. Token revocation

Cognito can revoke a refresh token through:

* `RevokeToken`.
* The `/oauth2/revoke` endpoint.
* Global user sign-out operations.

Revoking a refresh token also invalidates access and ID tokens associated with the same token lineage. It does not automatically revoke unrelated refresh-token sessions for the same user unless a broader sign-out operation is used. ([AWS Documentation][23])

---

# 39. Logout is more than deleting browser state

A complete logout may involve:

```text
1. Delete local application session.

2. Remove secure token cookies.

3. Revoke refresh token where required.

4. Redirect to Cognito logout endpoint.

5. Clear or terminate upstream identity-provider session if supported.

6. Redirect only to an allow-listed logout URL.
```

Cognito’s logout endpoint requires configured redirect/logout behaviour and supports `state` when redirecting through a new authentication flow. ([AWS Documentation][24])

Logging out of Cognito does not always sign the user out of Google, Microsoft or another upstream identity provider.

---

# Part 3 — Passwords, passwordless and passkeys

# 40. Password authentication

Cognito supports username-and-password authentication.

For custom applications, preferred secure flows include:

```text
Secure Remote Password:
USER_SRP_AUTH

Choice-based authentication:
USER_AUTH
```

AWS recommends SRP when password-based direct API authentication is required because the password itself is not sent as the direct proof in the same way as basic password authentication. ([AWS Documentation][10])

---

# 41. Password policy

A production password policy should consider:

* Minimum length.
* Complexity requirements.
* Temporary-password lifetime.
* Password history.
* Account-recovery methods.
* Compromised-credential detection.
* MFA or passkey availability.
* User experience.

Password history is available in applicable feature plans. ([AWS Documentation][6])

Long passwords and passphrases are generally more useful than forcing excessive periodic password resets without evidence of compromise.

---

# 42. Passwordless OTP sign-in

Cognito supports passwordless sign-in using:

```text
Email one-time passwords
SMS one-time passwords
```

The user enters an email address or phone number, receives a code and completes authentication without a traditional password. ([AWS Documentation][2])

Benefits:

* No password to remember.
* No password reuse.
* Simpler onboarding.

Risks:

* Email account compromise.
* SIM-swapping attacks.
* Message-delivery delays.
* SMS cost.
* Phishing of OTP codes.
* Dependence on communication-channel availability.

---

# 43. Passkeys

Passkeys use WebAuthn public-key credentials.

```text
User device
    |
    | Signs challenge with private key
    v
Cognito
    |
    | Verifies with public key
    v
Authenticated session
```

The private key remains protected by the user’s device or credential provider.

Benefits:

* Phishing-resistant authentication.
* No shared password.
* No password database secret for that credential.
* Device biometrics or PIN can provide user verification.

Cognito managed login can handle passkey authentication, and Cognito APIs can also support passkey workflows in custom applications. ([AWS Documentation][25])

---

# 44. Passkey relying-party ID

WebAuthn credentials are bound to a relying-party identity, commonly related to the authentication domain.

For example:

```text
Authentication domain:
auth.yourdatascientist.tech

Relying-party ID:
yourdatascientist.tech
or an appropriately scoped supported domain
```

Changing domains or relying-party configuration after users create passkeys can affect whether existing credentials remain usable.

Plan the final production domain before large-scale passkey enrolment.

---

# 45. Choice-based authentication

Choice-based authentication lets the user or application select among configured factors such as:

* Password.
* Email OTP.
* SMS OTP.
* Passkey.

The app client uses the `USER_AUTH` authentication flow, and Cognito returns the appropriate challenge sequence. ([AWS Documentation][25])

Example:

```text
Sign in using:
[ Passkey ]
[ Email code ]
[ Password ]
```

This supports gradual migration away from passwords.

---

# Part 4 — Multi-factor authentication

# 46. MFA options

Depending on the user-pool feature plan and configuration, Cognito can use:

```text
TOTP authenticator app
SMS one-time code
Email one-time code
Passkey with required user verification
```

([AWS Documentation][26])

## TOTP

Examples:

* Authenticator application.
* Time-based six-digit code.
* No SMS delivery dependency.

## SMS MFA

Convenient but exposed to:

* SIM swapping.
* Phone-number takeover.
* Mobile-network delay.

## Email MFA

Accessible but dependent on email-account security.

---

# 47. MFA modes

```text
OFF
OPTIONAL
REQUIRED
```

## Optional

Individual users can configure MFA.

## Required

Applicable users must enrol and complete an additional factor.

## Off

Cognito does not request traditional MFA.

Adaptive authentication generally requires MFA to be optional because Cognito decides when to challenge based on session risk. ([AWS Documentation][27])

---

# 48. Passwordless and MFA nuance

A passwordless OTP is already being used as the first authentication factor, so that same session cannot simply treat the same method as an independent second factor.

Cognito’s authentication-method availability depends on the first factor, user settings and pool configuration. A passkey requiring user verification can satisfy MFA requirements when WebAuthn MFA is configured appropriately. ([AWS Documentation][28])

Design factors as an authentication system—not merely as a checklist saying “MFA enabled.”

---

# 49. Account recovery and MFA

Avoid using the same delivery attribute in a contradictory way.

Example:

```text
Phone number used for SMS MFA
and
phone number expected as sole password-recovery channel
```

If the phone is unavailable, both sign-in and recovery can fail.

Recommended:

```text
TOTP for MFA
+
Verified email for recovery
```

or another carefully tested combination.

---

# 50. Trusted devices

Cognito can track devices and optionally allow users to trust a device so they do not receive an MFA prompt on every sign-in.

Device tracking uses device identifiers and Cognito’s device authentication flow. ([AWS Documentation][29])

Use trusted-device behaviour carefully for:

* Shared computers.
* Public devices.
* High-risk administrative accounts.
* Financial actions.

A trusted device should not automatically authorize every sensitive operation.

---

# Part 5 — Federation

# 51. Identity federation

Federation allows users to authenticate through another identity provider.

```text
User
  |
  v
Cognito managed login
  |
  ├── Google
  ├── Apple
  ├── Facebook
  ├── Enterprise OIDC
  └── Enterprise SAML
  |
  v
Cognito tokens
  |
  v
Application
```

The application receives a consistent Cognito token model even when upstream authentication comes from different providers. ([AWS Documentation][30])

---

# 52. Social federation

Typical social providers include:

```text
Google
Apple
Facebook
Login with Amazon
```

The provider authenticates the user.

Cognito:

* Receives the provider response.
* Maps attributes.
* Creates or updates the user-pool profile.
* Issues Cognito tokens to your app.

This prevents every application backend from implementing each provider’s token rules independently.

---

# 53. OIDC federation

OIDC federation is common for modern enterprise identity providers.

```text
Application
    |
    v
Cognito
    |
    v
Enterprise OIDC IdP
    |
    v
Cognito callback
    |
    v
Cognito tokens
```

Cognito uses OIDC discovery and provider endpoints to validate authentication and obtain user attributes. ([AWS Documentation][31])

Examples:

* Okta.
* Auth0.
* Microsoft Entra ID through OIDC.
* Keycloak.
* JumpCloud.

---

# 54. SAML federation

SAML is common in established enterprises.

```text
Cognito:
Service provider

Enterprise identity system:
SAML identity provider
```

Flow:

```text
User chooses enterprise login
        |
        v
Cognito redirects to SAML IdP
        |
        v
User authenticates
        |
        v
SAML assertion returned
        |
        v
Cognito maps attributes and issues tokens
```

SAML is suitable when the organisation’s workforce identity system already standardizes on SAML.

---

# 55. Attribute mapping

External provider claim:

```text
given_name = Vivek
surname    = Saroj
department = Engineering
```

Cognito attributes:

```text
given_name
family_name
custom:department
```

Plan mappings carefully because:

* Required attributes must be supplied.
* Immutable target attributes cannot be updated repeatedly.
* Provider formats differ.
* Missing claims can prevent user creation.
* Changed email addresses can affect account linking.

---

# 56. Federated user lifecycle

On first successful federation, Cognito can create a user-pool profile.

```text
First sign-in:
Create federated profile

Later sign-in:
Update mapped mutable attributes
```

Your application should define:

* Which provider owns each attribute.
* Whether users can edit mapped attributes.
* How accounts are disabled.
* How provider deprovisioning reaches Cognito.
* How duplicate identities are linked.

Federation is authentication—not complete user lifecycle governance.

---

# 57. Duplicate accounts

A user might register locally:

```text
vivek@example.com
```

and later sign in through Google with the same email.

Without deliberate linking, Cognito may treat these as distinct identities.

Risks:

* Duplicate profiles.
* Separate subscription state.
* Split audit history.
* Incorrect tenant membership.

Account-linking should happen only after sufficiently strong identity verification. Never link users solely because an unverified email string matches.

---

# 58. Inbound-federation trigger

The inbound-federation Lambda trigger can transform incoming federated attributes before Cognito creates or updates the user.

Use cases:

* Map provider groups into Cognito groups.
* Normalize provider attributes.
* Apply tenant information.
* Reject unsupported identities.
* Convert provider-specific fields.

Cognito can expose provider token, ID-token and UserInfo data to this trigger for applicable OIDC and social federation. ([AWS Documentation][32])

---

# Part 6 — Groups, claims and API authorization

# 59. User-pool groups

Groups provide role-based categorization.

Example:

```text
TodoUsers
TodoManagers
TodoAdministrators
SupportReadOnly
```

Tokens can include:

```json
{
  "cognito:groups": [
    "TodoManagers",
    "TodoUsers"
  ]
}
```

Groups can also be associated with IAM roles for identity-pool role selection. ([AWS Documentation][33])

---

# 60. Group precedence

Groups can have precedence values.

```text
Administrators:
precedence 1

Managers:
precedence 10

Users:
precedence 100
```

Lower values have higher priority.

The preferred group role can appear in:

```text
cognito:preferred_role
```

If equally ranked groups have conflicting role ARNs, Cognito does not select one preferred role automatically. ([AWS Documentation][33])

---

# 61. Groups are not complete authorization

A group can answer:

```text
Is this user an administrator?
```

It does not automatically answer:

```text
May this administrator modify tenant 38?
May this user read todo 501?
Does this user own project 22?
```

Use group claims for coarse RBAC.

Use backend authorization for:

* Resource ownership.
* Tenant isolation.
* Context-sensitive permissions.
* Transaction-specific policy.
* Time or state-dependent access.

---

# 62. Custom attributes versus groups

## Custom attribute

```text
custom:tenantId = tenant-38
custom:plan = premium
```

Good for stable user-profile metadata.

## Group

```text
TodoAdministrators
BillingManagers
```

Good for role membership.

Limit custom claims in tokens to values that:

* Are actually needed.
* Are safe to expose to clients.
* Do not change every few seconds.
* Fit token-size limits.
* Can tolerate token staleness until refresh.

---

# 63. Pre-token generation trigger

A pre-token generation Lambda trigger can customize token claims before Cognito issues tokens.

Use cases:

* Add tenant ID.
* Override groups.
* Add entitlements.
* Add custom access-token scopes.
* Remove unnecessary claims.
* Add M2M authorization context.

([AWS Documentation][34])

Example conceptual response:

```json
{
  "claimsAndScopeOverrideDetails": {
    "idTokenGeneration": {
      "claimsToAddOrOverride": {
        "tenantId": "tenant-38"
      }
    },
    "accessTokenGeneration": {
      "claimsToAddOrOverride": {
        "subscription": "premium"
      },
      "scopesToAdd": [
        "todo-api/reports.read"
      ]
    }
  }
}
```

Avoid querying a slow database on every token generation unless the dependency is highly available and latency is acceptable.

---

# 64. OAuth scopes

Scopes express permitted API operations.

Examples:

```text
todo-api/todos.read
todo-api/todos.write
todo-api/todos.delete
todo-api/reports.read
```

An API verifies that the access token contains the scope required by the endpoint.

```text
GET /todos
requires:
todo-api/todos.read

POST /todos
requires:
todo-api/todos.write
```

Cognito custom scopes are defined through resource servers. ([AWS Documentation][16])

---

# 65. Resource server

A Cognito resource server represents a protected API.

```text
Resource-server identifier:
todo-api

Scopes:
todos.read
todos.write
reports.read
```

Token representation:

```text
todo-api/todos.read
todo-api/todos.write
```

The API should validate:

* Token signature.
* Issuer.
* Expiration.
* Token use.
* Client/audience.
* Required scope. ([AWS Documentation][16])

---

# 66. Scope design

Bad scopes:

```text
admin
read
write
```

They are too broad and may conflict across APIs.

Better:

```text
todo-api/todos.read
todo-api/todos.write
billing-api/invoices.read
billing-api/payments.create
```

Avoid one scope per individual record.

Scopes should represent stable API capabilities.

---

# 67. M2M authorization design

```text
Client:
todo-reporting-service

Allowed scopes:
todo-api/reports.read

Not allowed:
todo-api/todos.delete
```

Create a separate confidential app client for each machine workload.

Benefits:

* Independent secret rotation.
* Clear audit identity.
* Least-privilege scopes.
* Easy revocation.
* Separate rate and cost attribution.

Do not reuse one M2M client secret across every microservice.

---

# Part 7 — Identity pools and AWS credentials

# 68. When to use an identity pool

Use an identity pool when the client must directly call AWS services.

Examples:

* Mobile app uploads a file directly to S3.
* Browser accesses a user-specific AppSync IAM endpoint.
* Game client writes permitted telemetry.
* User accesses a restricted DynamoDB partition.
* Guest receives temporary read-only credentials.

If every AWS operation occurs through your application API, you might not need an identity pool.

---

# 69. Identity-pool flow

```text
User authenticates
      |
      v
Cognito user-pool ID token
      |
      v
Identity pool
      |
      v
AWS STS
      |
      v
Temporary access key
Temporary secret key
Session token
      |
      v
Signed AWS API requests
```

Identity pools translate trusted authentication claims into an AWS STS role session. ([AWS Documentation][35])

---

# 70. Temporary AWS credentials

Identity-pool credentials are:

* Short lived.
* Scoped by IAM role.
* Automatically refreshable by compatible SDKs.
* Not permanent IAM-user credentials.

The client uses them to sign AWS API requests with Signature Version 4.

Do not return permanent AWS access keys from your backend to a browser or mobile device.

---

# 71. Authenticated and guest roles

An identity pool can have:

```text
Authenticated role
Unauthenticated guest role
```

Example:

```text
Authenticated:
Upload to own S3 prefix

Guest:
Read public application configuration
```

Guest access should be disabled unless there is a clear requirement. Identity pools can explicitly activate or deactivate unauthenticated identities. ([AWS Documentation][3])

---

# 72. Identity-pool trust policy

Example authenticated-role trust:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "cognito-identity.amazonaws.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "cognito-identity.amazonaws.com:aud": "ap-south-1:identity-pool-id"
        },
        "ForAnyValue:StringLike": {
          "cognito-identity.amazonaws.com:amr": "authenticated"
        }
      }
    }
  ]
}
```

The `aud` condition restricts the role to one identity pool. AWS recommends constraining identity-pool role trust to the specific pool. ([AWS Documentation][3])

---

# 73. User-specific S3 access

IAM policy concept:

```json
{
  "Effect": "Allow",
  "Action": [
    "s3:GetObject",
    "s3:PutObject"
  ],
  "Resource": "arn:aws:s3:::todo-user-files/${cognito-identity.amazonaws.com:sub}/*"
}
```

Architecture:

```text
User 104 temporary role session
        |
        v
s3://todo-user-files/<identity-id>/*
```

Ensure the identifier used in the S3 prefix matches the identity-pool principal identifier—not an untrusted client-provided value.

---

# 74. Role mapping

Identity pools can select IAM roles using:

* A default authenticated role.
* Token-claim rules.
* `cognito:preferred_role`.
* Group-associated roles.

([AWS Documentation][36])

Example:

```text
Token group:
PremiumUsers
    |
    v
Identity pool role mapping
    |
    v
PremiumUserAwsRole
```

Role mapping is AWS-resource authorization, separate from API scope authorization.

---

# 75. Attribute-based access control

You can map identity-provider claims to principal tags for IAM policy decisions.

Concept:

```text
Token claim:
tenantId = tenant-38

STS principal tag:
tenantId = tenant-38
```

IAM policy condition:

```json
{
  "Condition": {
    "StringEquals": {
      "s3:ExistingObjectTag/TenantId": "${aws:PrincipalTag/tenantId}"
    }
  }
}
```

ABAC is powerful but requires strict control of which claims are trusted and how they are mapped.

Never allow users to arbitrarily edit an attribute that becomes an IAM authorization tag.

---

# Part 8 — Lambda triggers

# 76. Cognito Lambda triggers

User pools can invoke Lambda at authentication and user-lifecycle stages.

Common triggers include:

```text
Pre sign-up
Post confirmation
Pre authentication
Post authentication
Custom message
User migration
Pre token generation
Define auth challenge
Create auth challenge
Verify auth challenge response
Custom email sender
Custom SMS sender
Inbound federation
```

([AWS Documentation][37])

Lambda triggers must be in the same Region as the user pool. ([AWS Documentation][38])

---

# 77. Pre sign-up trigger

Use before a new local or federated user is created.

Examples:

* Restrict email domain.
* Require invitation code.
* Auto-confirm trusted administrative imports.
* Auto-verify attributes in controlled workflows.
* Reject disposable email domains.
* Enforce tenant onboarding rules.

Do not put an unreliable external API directly in the sign-up path without timeout and failure planning.

---

# 78. Post confirmation trigger

Runs after successful user confirmation.

Use for:

* Create application profile.
* Publish `UserRegistered` event.
* Assign default application data.
* Start onboarding workflow.
* Send internal notification.

Make it idempotent because operational retries or administrative activity can repeat surrounding workflows.

Do not use it as the only durable source of user creation if the downstream effect is business-critical; publish through a reliable outbox or reconciliation process where necessary.

---

# 79. Pre authentication trigger

Runs before authentication completes.

Use for:

* Block suspended application accounts.
* Enforce tenant state.
* Apply custom risk rules.
* Restrict specific application clients.
* Require migration completion.

Keep it fast and highly available because failure can prevent users from signing in.

---

# 80. Post authentication trigger

Runs after successful authentication.

Use for:

* Security audit event.
* Last-login metadata.
* Login analytics.
* Asynchronous account maintenance.

Avoid synchronous heavy work such as:

* Generating reports.
* Calling several external APIs.
* Large database updates.

Publish an event and let downstream services process it asynchronously.

---

# 81. Custom-message trigger

Customizes Cognito communications such as:

* Verification messages.
* Invitation messages.
* Password-reset messages.
* MFA messages.

Use for:

* Branding.
* Localization.
* Tenant-specific wording.
* Security guidance.

Never include passwords, tokens or unnecessary personal information in message content.

---

# 82. User-migration trigger

The migration trigger supports gradual migration from an existing user directory.

```text
User signs in
      |
      v
Not found in Cognito
      |
      v
User migration Lambda
      |
      v
Validate against legacy directory
      |
      v
Create user in Cognito
```

Benefits:

* No forced password reset for all users.
* Users migrate at normal sign-in.
* Gradual operational cutover.

Risks:

* Legacy directory remains required during migration.
* Migration Lambda becomes part of sign-in availability.
* Password validation must be handled securely.
* Inactive users never migrate automatically.

---

# 83. Custom authentication challenge

Custom challenge triggers let you implement additional challenge logic.

Three cooperating triggers are used:

```text
Define auth challenge
Create auth challenge
Verify auth challenge response
```

([AWS Documentation][39])

Possible uses:

* Custom challenge-response.
* External approval.
* Special device attestation.
* Additional risk challenge.

Do not invent insecure authentication merely because custom challenges are flexible.

---

# 84. Trigger failure considerations

A trigger can fail because of:

* Lambda timeout.
* Missing invoke permission.
* Incorrect response structure.
* Exception.
* VPC networking.
* Downstream dependency.
* Concurrency throttling.
* Deployment error.

Managed-login federation errors can result from malformed trigger responses. ([AWS Documentation][40])

Every authentication-path Lambda should have:

* Bounded execution time.
* Structured logs.
* Alarms.
* Reserved or protected concurrency where appropriate.
* Safe deployment strategy.
* Minimal dependencies.

---

# Part 9 — Threat protection and security

# 85. Cognito security layers

```text
Managed login / Cognito APIs
        |
        ├── AWS WAF
        ├── Password or passkey controls
        ├── MFA
        ├── Compromised credential detection
        ├── Adaptive authentication
        ├── User-existence error protection
        ├── Token revocation
        ├── CloudTrail
        └── Threat-protection logs
```

Authentication is a high-value attack surface. Apply defence in depth.

---

# 86. AWS WAF for Cognito

AWS WAF can inspect requests sent to supported Cognito user-pool endpoints.

Use rules for:

* Rate-based blocking.
* IP reputation.
* Geographic restrictions.
* Known malicious request patterns.
* Bot mitigation.
* Allow lists for internal portals.

([AWS Documentation][41])

Test WAF rules in count mode before blocking production authentication traffic.

---

# 87. Compromised-credential detection

Cognito can evaluate password-based sign-in credentials against compromise indicators and take configured action when credentials appear to have been exposed elsewhere. ([AWS Documentation][42])

Possible responses include:

* Allow and log.
* Require additional verification.
* Block authentication.
* Notify users.

This applies to password-based users, not passwordless passkeys.

---

# 88. Adaptive authentication

Adaptive authentication evaluates sign-in risk using contextual information.

Signals can include:

* IP address.
* Device information.
* Browser/user agent.
* Request headers.
* Sign-in history.
* Location patterns.

Cognito can then:

* Allow authentication.
* Require MFA.
* Block authentication.
* Generate risk logs and metrics. ([AWS Documentation][43])

Use audit mode before enforcement to understand normal user behaviour and false-positive risk.

---

# 89. Threat-protection scope

Threat protection can be configured:

```text
At user-pool level
or
Per app client
```

App-client settings can override broader pool settings. ([AWS Documentation][44])

Example:

```text
Public customer portal:
Adaptive risk enforcement

Internal test client:
Audit only

M2M client:
Separate controls
```

---

# 90. Prevent user-existence disclosure

Authentication errors should avoid confirming whether a username exists.

Bad:

```text
User not found:
"No account exists for vivek@example.com"

Wrong password:
"Password is incorrect"
```

An attacker can enumerate registered users.

Better:

```text
"Incorrect username or password"
```

Configure app clients to prevent user-existence errors where supported and ensure custom triggers do not reintroduce the leak.

---

# 91. Case sensitivity

For email-based usernames, case-insensitive configuration is normally safer.

Without it:

```text
Vivek@example.com
vivek@example.com
```

might behave as separate usernames depending on pool settings.

Cognito user-pool case sensitivity is a security and identity-consistency configuration that should be decided when creating the pool. ([AWS Documentation][26])

Changing identity-normalization behaviour after launch can be difficult.

---

# 92. Deletion protection

Enable user-pool deletion protection in production.

This reduces the chance that:

* Terraform destroys the pool.
* A script deletes it.
* An administrator removes it accidentally.

Deletion protection is one of Cognito’s documented security controls. ([AWS Documentation][26])

Also use:

```hcl
lifecycle {
  prevent_destroy = true
}
```

for an additional Terraform safeguard.

---

# 93. Secret-hash handling

Confidential Cognito app clients can require `SECRET_HASH` in applicable direct authentication API calls.

It is calculated using:

```text
HMAC-SHA256(
  client_secret,
  username + client_id
)
```

and base64 encoding.

A common failure is:

```text
Unable to verify secret hash for client
```

Public clients should normally not have a client secret.

---

# Part 10 — Multi-tenancy

# 94. Multi-tenant identity patterns

Common patterns:

```text
One user pool per tenant

One shared user pool
+
one app client per tenant

One shared user pool
+
tenant claims/groups
```

Cognito provides guidance for user-pool, group-based and scope-based multi-tenancy designs. ([AWS Documentation][45])

---

# 95. One user pool per tenant

```text
Tenant A → User pool A
Tenant B → User pool B
Tenant C → User pool C
```

Advantages:

* Strong isolation.
* Separate branding.
* Separate IdPs.
* Separate policies.
* Easier tenant deletion.

Disadvantages:

* Operational overhead.
* Infrastructure duplication.
* Quota management.
* Complex cross-tenant user access.
* More app-client and domain management.

Strong fit for highly regulated or independently configured enterprise tenants.

---

# 96. Shared user pool

```text
All tenants
    |
    v
Shared user pool
    |
    v
tenantId claim
```

Advantages:

* Simpler operations.
* One authentication domain.
* Easier common user experience.
* Shared federation architecture.

Risks:

* Tenant isolation depends on correct claims and backend checks.
* Users may belong to several tenants.
* Group counts and claim size can grow.
* One configuration affects all tenants.

---

# 97. Tenant ID in tokens

Example:

```json
{
  "sub": "user-id",
  "tenantId": "tenant-38",
  "scope": "todo-api/todos.read"
}
```

Backend query:

```sql
SELECT *
FROM todos
WHERE tenant_id = :trustedTenantId
  AND todo_id = :todoId;
```

The trusted tenant ID comes from the validated access token—not from the request body.

Bad:

```json
{
  "tenantId": "tenant-99"
}
```

A client must not be able to choose arbitrary tenant authorization.

---

# 98. Users in multiple tenants

A single `tenantId` claim may be insufficient if one person belongs to several organisations.

Options:

* User selects active tenant and receives a tenant-bound session.
* Store membership in an authorization service.
* Use Verified Permissions.
* Issue tenant-specific access tokens.
* Use separate app clients or user pools for strict isolation.

Avoid putting thousands of tenant memberships inside one JWT.

---

# Part 11 — Resilience and disaster recovery

# 99. Regional nature of user pools

A Cognito user pool is created in an AWS Region and stores user-profile data there. ([AWS Documentation][46])

Traditional architecture:

```text
User pool:
ap-south-1

Application:
ap-south-1
```

Before designing disaster recovery, determine whether the pool is eligible for Cognito’s newer native multi-Region replication.

---

# 100. Multi-Region replication

Cognito now supports multi-Region replication for eligible user pools.

Architecture:

```text
Primary Cognito user pool
ap-south-1
        |
        | Managed replication
        v
Replica Cognito user pool
Secondary Region
```

Registered users can continue authenticating through the replica during supported regional-failure scenarios. ([AWS Documentation][47])

---

# 101. Multi-Region requirements and behaviour

Current documented characteristics include:

* Essentials or Plus feature plan required.
* Eligible modern user-pool infrastructure required.
* A secondary replica Region.
* Multi-Region KMS and issuer-related configuration prerequisites.
* Custom domain required for automatic failover.
* Primary Region remains authoritative for user-directory writes such as sign-up and password-reset operations.
* Secondary can handle supported sign-in and token operations during failover. ([AWS Documentation][47])

Not every existing pool is immediately eligible.

---

# 102. Regional failover architecture

```text
Application
    |
    v
auth.yourdatascientist.tech
    |
    v
Cognito multi-Region custom domain
    |
    ├── Primary: ap-south-1
    └── Replica: secondary Region
```

During failover:

* Authentication traffic can move to the replica.
* Application APIs must also be available in the secondary Region.
* Redirect URLs and DNS must remain valid.
* Regional Lambda triggers and messaging settings require appropriate secondary configuration.
* Application data must have its own DR strategy.

Identity failover alone does not make the application multi-Region.

---

# 103. User export is not password backup

Cognito does not expose user passwords for export.

A profile-export process can preserve:

* User attributes.
* Group memberships.
* Some profile metadata.

It cannot recreate users’ password verifiers as a portable backup.

Therefore a home-grown secondary user pool may require:

* Password resets.
* Migration trigger.
* External identity federation.
* Native multi-Region replication.
* Carefully designed recovery procedures.

---

# Part 12 — Observability and auditing

# 104. CloudTrail

Cognito records user-pool API activity and managed-login-related operations in CloudTrail. ([AWS Documentation][48])

Use CloudTrail to investigate:

* User-pool configuration changes.
* App-client changes.
* User administration.
* Group modifications.
* Domain changes.
* Token or user-management API calls.

Send organisation trails to a protected central S3 bucket.

---

# 105. CloudWatch metrics

Cognito publishes user-pool and app-client metrics in:

```text
AWS/Cognito
```

Metrics can be dimensioned by user pool and app client. ([AWS Documentation][49])

Monitor:

* Sign-in success and failures.
* Token request activity.
* Throttling.
* Threat-protection risk results.
* Lambda-trigger errors.
* Messaging-delivery problems.
* Authentication latency from the application side.

---

# 106. Threat-protection logs

Threat-protection authentication events can be exported to:

* CloudWatch Logs.
* Amazon S3.
* Amazon Data Firehose.

([AWS Documentation][43])

Use these for:

* Sign-in-risk analysis.
* Suspicious IP investigation.
* Compromised-account detection.
* Security dashboards.
* Incident response.

Restrict access because authentication logs can contain sensitive identity context.

---

# 107. Application authentication metrics

Cognito metrics alone do not show the full user experience.

Add application metrics:

```text
Login attempts
Login successes
Login failures by reason
MFA challenge rate
MFA success rate
Password-reset requests
Password-reset success
Federation failures
Token refresh failures
Passkey registration rate
Passkey sign-in rate
P95 login duration
```

Never include passwords, OTPs, refresh tokens or complete access tokens in logs.

---

# 108. Recommended alarms

```text
Authentication failures spike
Cognito throttling appears
Lambda trigger errors > 0
Lambda trigger throttles > 0
SMS or email delivery failures increase
Federated sign-in failures increase
High-risk sign-ins increase
Compromised credentials detected
WAF blocks increase unexpectedly
Token endpoint errors increase
```

A sudden authentication-failure spike might indicate:

* Credential stuffing.
* Broken deployment.
* IdP outage.
* Incorrect callback URL.
* Expired client secret.
* DNS or certificate issue.

---

# Part 13 — Terraform implementation

# 109. Terraform user pool

```hcl
resource "aws_cognito_user_pool" "todoapp" {
  name = "production-todoapp"

  user_pool_tier = "ESSENTIALS"

  deletion_protection = "ACTIVE"

  username_attributes = [
    "email"
  ]

  auto_verified_attributes = [
    "email"
  ]

  username_configuration {
    case_sensitive = false
  }

  password_policy {
    minimum_length                   = 14
    require_lowercase                = true
    require_numbers                  = true
    require_symbols                  = true
    require_uppercase                = true
    temporary_password_validity_days = 3
    password_history_size            = 10
  }

  mfa_configuration = "OPTIONAL"

  software_token_mfa_configuration {
    enabled = true
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  admin_create_user_config {
    allow_admin_create_user_only = false
  }

  user_attribute_update_settings {
    attributes_require_verification_before_update = [
      "email"
    ]
  }

  tags = {
    Application = "TodoApp"
    Environment = "production"
    ManagedBy   = "Terraform"
  }

  lifecycle {
    prevent_destroy = true
  }
}
```

The current AWS Terraform provider supports user-pool feature plans and WebAuthn configuration as part of `aws_cognito_user_pool`; exact arguments should be validated against the provider version pinned by the project. ([Terraform Registry][50])

---

# 110. Passkey configuration

Conceptual Terraform configuration:

```hcl
resource "aws_cognito_user_pool" "todoapp" {
  # Other configuration omitted.

  web_authn_configuration {
    relying_party_id = "yourdatascientist.tech"
    user_verification = "required"
  }
}
```

Passkey settings must align with:

* The production authentication domain.
* Managed-login configuration.
* Enabled app-client authentication flows.
* MFA requirements.
* User-verification requirements.

Test the exact provider schema before applying because WebAuthn configuration has evolved alongside newer Cognito capabilities. ([Terraform Registry][50])

---

# 111. SPA app client

```hcl
resource "aws_cognito_user_pool_client" "web" {
  name         = "production-todoapp-web"
  user_pool_id = aws_cognito_user_pool.todoapp.id

  generate_secret = false

  allowed_oauth_flows_user_pool_client = true

  allowed_oauth_flows = [
    "code"
  ]

  allowed_oauth_scopes = [
    "openid",
    "email",
    "profile",
    aws_cognito_resource_server.todoapp.scope_identifiers["todos.read"],
    aws_cognito_resource_server.todoapp.scope_identifiers["todos.write"]
  ]

  callback_urls = [
    "https://app.yourdatascientist.tech/auth/callback"
  ]

  logout_urls = [
    "https://app.yourdatascientist.tech/"
  ]

  supported_identity_providers = [
    "COGNITO",
    "Google"
  ]

  explicit_auth_flows = [
    "ALLOW_USER_AUTH",
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]

  access_token_validity  = 15
  id_token_validity      = 15
  refresh_token_validity = 30

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }

  enable_token_revocation       = true
  prevent_user_existence_errors = "ENABLED"

  refresh_token_rotation {
    feature                    = "ENABLED"
    retry_grace_period_seconds = 10
  }

  read_attributes = [
    "email",
    "email_verified",
    "given_name",
    "family_name"
  ]

  write_attributes = [
    "given_name",
    "family_name"
  ]
}
```

The Terraform app-client resource supports OAuth flows, scopes, token validity, authentication-session validity and refresh-token rotation settings. ([Terraform Registry][51])

---

# 112. Resource server

```hcl
resource "aws_cognito_resource_server" "todoapp" {
  identifier = "todo-api"
  name       = "TodoApp API"

  user_pool_id = aws_cognito_user_pool.todoapp.id

  scope {
    scope_name        = "todos.read"
    scope_description = "Read todos"
  }

  scope {
    scope_name        = "todos.write"
    scope_description = "Create and update todos"
  }

  scope {
    scope_name        = "todos.delete"
    scope_description = "Delete todos"
  }

  scope {
    scope_name        = "reports.read"
    scope_description = "Read TodoApp reports"
  }
}
```

Tokens use scope names such as:

```text
todo-api/todos.read
todo-api/todos.write
```

---

# 113. Machine-to-machine app client

```hcl
resource "aws_cognito_user_pool_client" "reporting_service" {
  name         = "production-reporting-service"
  user_pool_id = aws_cognito_user_pool.todoapp.id

  generate_secret = true

  allowed_oauth_flows_user_pool_client = true

  allowed_oauth_flows = [
    "client_credentials"
  ]

  allowed_oauth_scopes = [
    aws_cognito_resource_server.todoapp.scope_identifiers["reports.read"]
  ]

  access_token_validity = 15

  token_validity_units {
    access_token = "minutes"
  }

  enable_token_revocation = true
}
```

Client-credentials grants issue access tokens for custom resource-server scopes and require a confidential client with a secret. ([AWS Documentation][16])

---

# 114. Prefix domain

```hcl
resource "aws_cognito_user_pool_domain" "prefix" {
  domain       = "todoapp-production"
  user_pool_id = aws_cognito_user_pool.todoapp.id

  managed_login_version = 2
}
```

Result:

```text
todoapp-production.auth.ap-south-1.amazoncognito.com
```

Managed-login version 2 selects the newer managed-login experience for the domain. ([AWS Documentation][52])

---

# 115. Custom domain and us-east-1 certificate

```hcl
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

resource "aws_acm_certificate" "cognito" {
  provider = aws.us_east_1

  domain_name       = "auth.yourdatascientist.tech"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_cognito_user_pool_domain" "custom" {
  domain       = "auth.yourdatascientist.tech"
  user_pool_id = aws_cognito_user_pool.todoapp.id

  certificate_arn = aws_acm_certificate.cognito.arn

  managed_login_version = 2
}
```

Cognito custom-domain ACM certificates must be in `us-east-1`, even when the pool is in `ap-south-1`. ([AWS Documentation][12])

Create DNS validation records and the Cognito alias record using Route 53 or the domain’s DNS provider.

---

# 116. Cognito group

```hcl
resource "aws_cognito_user_group" "administrators" {
  name         = "TodoAdministrators"
  user_pool_id = aws_cognito_user_pool.todoapp.id

  description = "TodoApp production administrators"

  precedence = 10
}
```

Groups can also reference an IAM role when identity-pool preferred-role selection is required. The provider manages groups through `aws_cognito_user_group`. ([Terraform Registry][53])

---

# 117. Google identity provider

```hcl
resource "aws_cognito_identity_provider" "google" {
  user_pool_id  = aws_cognito_user_pool.todoapp.id
  provider_name = "Google"
  provider_type = "Google"

  provider_details = {
    client_id        = var.google_client_id
    client_secret    = var.google_client_secret
    authorize_scopes = "openid email profile"
  }

  attribute_mapping = {
    email       = "email"
    username    = "sub"
    given_name  = "given_name"
    family_name = "family_name"
  }
}
```

Store the Google client secret securely rather than hardcoding it in normal Terraform source. Terraform state must also be protected because sensitive provider details can be stored there.

The AWS provider supports user-pool identity providers through `aws_cognito_identity_provider`. ([Terraform Registry][54])

---

# 118. Identity pool

```hcl
resource "aws_cognito_identity_pool" "todoapp" {
  identity_pool_name = "production-todoapp"

  allow_unauthenticated_identities = false

  cognito_identity_providers {
    client_id = aws_cognito_user_pool_client.web.id

    provider_name = (
      aws_cognito_user_pool.todoapp.endpoint
    )

    server_side_token_check = true
  }

  tags = {
    Application = "TodoApp"
    Environment = "production"
  }
}
```

The Terraform identity-pool resource supports Cognito user-pool providers and server-side token checking. ([Terraform Registry][55])

---

# 119. Authenticated identity-pool role

```hcl
data "aws_iam_policy_document" "identity_authenticated_trust" {
  statement {
    effect = "Allow"

    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]

    principals {
      type = "Federated"

      identifiers = [
        "cognito-identity.amazonaws.com"
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "cognito-identity.amazonaws.com:aud"

      values = [
        aws_cognito_identity_pool.todoapp.id
      ]
    }

    condition {
      test     = "ForAnyValue:StringLike"
      variable = "cognito-identity.amazonaws.com:amr"

      values = [
        "authenticated"
      ]
    }
  }
}

resource "aws_iam_role" "identity_authenticated" {
  name               = "production-todoapp-authenticated"
  assume_role_policy = data.aws_iam_policy_document.identity_authenticated_trust.json
}
```

---

# 120. User file policy

```hcl
data "aws_iam_policy_document" "user_files" {
  statement {
    sid    = "UserFileAccess"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]

    resources = [
      "${aws_s3_bucket.user_files.arn}/$${cognito-identity.amazonaws.com:sub}/*"
    ]
  }

  statement {
    sid    = "ListOwnPrefix"
    effect = "Allow"

    actions = [
      "s3:ListBucket"
    ]

    resources = [
      aws_s3_bucket.user_files.arn
    ]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"

      values = [
        "$${cognito-identity.amazonaws.com:sub}/*"
      ]
    }
  }
}

resource "aws_iam_role_policy" "identity_authenticated" {
  role   = aws_iam_role.identity_authenticated.id
  policy = data.aws_iam_policy_document.user_files.json
}
```

---

# 121. Identity-pool role attachment

```hcl
resource "aws_cognito_identity_pool_roles_attachment" "todoapp" {
  identity_pool_id = aws_cognito_identity_pool.todoapp.id

  roles = {
    authenticated = aws_iam_role.identity_authenticated.arn
  }

  role_mapping {
    identity_provider = (
      "${aws_cognito_user_pool.todoapp.endpoint}:${aws_cognito_user_pool_client.web.id}"
    )

    type                        = "Token"
    ambiguous_role_resolution   = "Deny"
  }
}
```

The provider exposes role attachments and role-mapping configuration through `aws_cognito_identity_pool_roles_attachment`. ([Terraform Registry][56])

---

# 122. Lambda-trigger permission

```hcl
resource "aws_lambda_permission" "cognito_pre_token" {
  statement_id  = "AllowCognitoPreToken"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.pre_token.function_name

  principal = "cognito-idp.amazonaws.com"

  source_arn = aws_cognito_user_pool.todoapp.arn
}
```

Then associate the function:

```hcl
resource "aws_cognito_user_pool" "todoapp" {
  # Other configuration omitted.

  lambda_config {
    pre_token_generation = aws_lambda_function.pre_token.arn
  }
}
```

Restrict the permission to the specific user-pool ARN.

---

# 123. API Gateway Cognito authorizer

For a REST API:

```hcl
resource "aws_api_gateway_authorizer" "cognito" {
  name        = "production-cognito"
  rest_api_id = aws_api_gateway_rest_api.todoapp.id

  type = "COGNITO_USER_POOLS"

  provider_arns = [
    aws_cognito_user_pool.todoapp.arn
  ]

  identity_source = "method.request.header.Authorization"
}
```

Method configuration can then require:

```text
todo-api/todos.read
todo-api/todos.write
```

as authorization scopes.

For HTTP APIs, use a JWT authorizer with the Cognito issuer and app-client audience.

---

# Part 14 — CLI and validation

# 124. Describe the user pool

```bash
aws cognito-idp describe-user-pool \
  --user-pool-id "$USER_POOL_ID" \
  --region ap-south-1
```

List app clients:

```bash
aws cognito-idp list-user-pool-clients \
  --user-pool-id "$USER_POOL_ID" \
  --region ap-south-1
```

Describe an app client:

```bash
aws cognito-idp describe-user-pool-client \
  --user-pool-id "$USER_POOL_ID" \
  --client-id "$CLIENT_ID" \
  --region ap-south-1
```

---

# 125. Create an administrative test user

```bash
aws cognito-idp admin-create-user \
  --user-pool-id "$USER_POOL_ID" \
  --username "vivek@example.com" \
  --user-attributes \
    Name=email,Value=vivek@example.com \
    Name=email_verified,Value=true \
  --temporary-password "$TEMPORARY_PASSWORD" \
  --region ap-south-1
```

Never place real passwords directly into shell history.

Use a secure environment-variable or secret mechanism.

---

# 126. Add a user to a group

```bash
aws cognito-idp admin-add-user-to-group \
  --user-pool-id "$USER_POOL_ID" \
  --username "vivek@example.com" \
  --group-name "TodoAdministrators" \
  --region ap-south-1
```

Verify:

```bash
aws cognito-idp admin-list-groups-for-user \
  --user-pool-id "$USER_POOL_ID" \
  --username "vivek@example.com" \
  --region ap-south-1
```

The next token issuance or refresh should reflect the updated group claims.

Existing access tokens do not magically change before they expire or are refreshed.

---

# 127. Inspect OIDC discovery

Discovery endpoint concept:

```text
https://cognito-idp.ap-south-1.amazonaws.com/<USER_POOL_ID>/.well-known/openid-configuration
```

JWKS concept:

```text
https://cognito-idp.ap-south-1.amazonaws.com/<USER_POOL_ID>/.well-known/jwks.json
```

For multi-Region-enabled configurations, use the issuer and discovery model recommended for that pool rather than constructing assumptions manually. ([AWS Documentation][21])

---

# 128. Revoke a refresh token

```bash
aws cognito-idp revoke-token \
  --client-id "$CLIENT_ID" \
  --token "$REFRESH_TOKEN" \
  --region ap-south-1
```

Confidential clients may also require the client secret.

Do not print refresh tokens into shared terminal logs or CI/CD output.

---

# Part 15 — Troubleshooting

# 129. `redirect_mismatch`

Cause:

```text
redirect_uri in request
does not exactly match
an app-client callback URL
```

Check:

* Scheme: `https`.
* Hostname.
* Port.
* Path.
* Trailing slash.
* URL encoding.
* Environment.
* Exact case where relevant.

Examples:

```text
Configured:
https://app.example.com/auth/callback

Requested:
https://app.example.com/auth/callback/
```

These can be treated as different URLs.

---

# 130. `invalid_client`

Possible causes:

* Wrong client ID.
* Client secret missing.
* Incorrect client secret.
* Public client treated as confidential.
* Confidential client sent wrong authentication method.
* Client belongs to another user pool.
* Secret was rotated or client recreated.
* Wrong Region or domain.

Check app-client configuration before changing user passwords.

---

# 131. `invalid_grant`

Possible causes:

* Authorization code expired.
* Code already redeemed.
* Redirect URI differs from authorization request.
* PKCE verifier is incorrect.
* Refresh token expired.
* Refresh token revoked.
* Token belongs to another app client.
* Grant is not enabled.

Authorization codes are short lived and single use. Cognito currently documents a five-minute code lifetime. ([AWS Documentation][13])

---

# 132. `SECRET_HASH` error

Error:

```text
Unable to verify secret hash for client
```

Check:

* App client has a secret.
* Correct client ID.
* Correct client secret.
* Correct username value.
* HMAC-SHA256 formula.
* Correct base64 encoding.
* Secret was not accidentally URL encoded.

For browser and mobile clients, use an app client without a secret.

---

# 133. JWT accepted by browser but rejected by API

Check:

```text
[ ] Correct token type
[ ] Access token, not ID token
[ ] Correct issuer
[ ] Correct user pool
[ ] Correct app client
[ ] Token not expired
[ ] Required scope present
[ ] JWKS refreshed
[ ] Correct Region
[ ] Authorization header format
```

A token from the development pool should not authorize the production API.

---

# 134. Group was added but token has no new group

Tokens are snapshots of claims at issuance time.

Flow:

```text
Token issued
      |
      v
Administrator adds group
      |
      v
Existing token remains unchanged
```

Obtain a new token through:

* Refresh.
* Reauthentication.
* Session renewal.

Do not expect group changes to alter already issued JWT payloads.

---

# 135. User cannot receive email code

Check:

* Email is valid.
* Email is verified where required.
* SES configuration.
* SES sandbox status.
* Verified sender/domain.
* Suppression list.
* Region.
* Daily sending limits.
* Spam folder.
* Custom-message trigger.
* Custom-email-sender trigger.
* Account-recovery configuration.

Production email should normally use a verified organisational domain rather than depending solely on generic default delivery.

---

# 136. User cannot receive SMS code

Check:

* Phone number is E.164 formatted.
* SMS role trust and permissions.
* SNS SMS spending limit.
* Country-specific registration.
* Origination identity.
* Sandbox restrictions.
* Carrier filtering.
* Region.
* MFA and recovery conflict.
* Custom SMS trigger.

SMS delivery has cost and regulatory dependencies that differ by destination country.

---

# 137. Passkey sign-in not offered

Check:

* User-pool feature plan.
* Passkeys enabled as a primary factor.
* App client permits `USER_AUTH`.
* Managed-login branding/version supports the flow.
* WebAuthn relying-party ID.
* Authentication domain.
* Browser support.
* Secure HTTPS context.
* MFA/passkey factor configuration.
* User has registered a passkey.

Passkey configuration is tied closely to the domain and relying-party identity.

---

# 138. Federated user has missing attributes

Check:

* Upstream provider returned the claim.
* Requested OIDC scopes.
* SAML assertion contents.
* Cognito attribute mapping.
* Target attribute is mutable.
* Required attributes.
* Provider UserInfo endpoint.
* Inbound-federation trigger.
* App-client readable attributes.

Do not assume every provider returns an email address or verified-email claim.

---

# 139. Duplicate federated profiles

Check:

* Local user already exists.
* Upstream provider subject changed.
* Email was unverified.
* Account-linking process.
* Multiple IdPs.
* User changed organisation.
* Username mapping.
* Migration process.

Do not merge accounts automatically based only on display name or an unverified email claim.

---

# 140. Identity-pool `AccessDenied`

Check:

* Identity-pool ID.
* Provider mapping.
* Token issuer.
* App-client ID.
* IAM role trust `aud`.
* IAM role trust `amr`.
* Role attachment.
* Role-mapping rules.
* IAM permissions.
* Resource policy.
* Principal-tag mapping.
* Credentials expired.

Inspect both:

```text
Can the identity assume the role?
```

and:

```text
Does the assumed role permit the requested action?
```

---

# 141. Custom domain remains unavailable

Check:

* Certificate exists in `us-east-1`.
* Certificate status is `ISSUED`.
* Hostname matches certificate.
* Parent domain resolves.
* Alias DNS record exists.
* Domain is not already attached elsewhere.
* Cognito domain status.
* DNS propagation.
* Recent certificate replacement.

A new custom domain can take several minutes to become available, and certificate updates can take longer to distribute. ([AWS Documentation][9])

---

# 142. Login redirect loop

Possible causes:

* Application does not persist OAuth state.
* Callback immediately starts authentication again.
* Authorization code exchange fails.
* Session cookie blocked.
* `SameSite` cookie issue.
* Callback URL mismatch.
* Wrong environment client ID.
* Token validation rejects valid token.
* Application loses PKCE verifier.
* Upstream IdP session loop.

Trace one complete browser flow with network tools while ensuring tokens and codes are not exposed in support logs.

---

# 143. `TooManyRequestsException`

Cognito APIs have service quotas.

Causes:

* Login storm.
* Aggressive token refresh.
* Retry loop.
* Bot attack.
* One shared M2M client at high volume.
* User import or administration burst.
* Application repeatedly calls user APIs.

Actions:

* Exponential backoff and jitter.
* Cache M2M access tokens until near expiration.
* Reduce unnecessary token refreshes.
* Use AWS WAF.
* Request quota increase before launch.
* Separate app clients and workloads.
* Monitor throttling.

Do not request a new client-credentials token for every API request.

---

# 144. Terraform wants to recreate the user pool

This is dangerous because Cognito user-pool replacement can affect the complete user directory.

Check:

* Immutable attribute changes.
* Username configuration changes.
* Schema changes.
* Provider-version upgrade.
* Changed resource names.
* Imported state.
* Manual console drift.
* Custom attribute constraints.
* Region or account mismatch.

Use:

```hcl
lifecycle {
  prevent_destroy = true
}
```

and inspect every plan involving:

```text
-/+ aws_cognito_user_pool
```

Never approve user-pool replacement casually.

---

# 145. Production readiness checklist

```text
[ ] User pool versus identity pool responsibility is documented
[ ] Cognito feature plan is intentionally selected
[ ] Separate app clients exist per application type
[ ] Separate app clients exist per environment
[ ] Browser and mobile clients have no client secret
[ ] Authorization code + PKCE is used
[ ] Implicit grant is disabled
[ ] M2M clients are confidential
[ ] M2M clients have least-privilege custom scopes
[ ] Client secrets are stored in Secrets Manager
[ ] Callback URLs are exact and allow-listed
[ ] Logout URLs are exact and allow-listed
[ ] OAuth state is validated
[ ] OIDC nonce is validated where used
[ ] Access tokens authorize APIs
[ ] ID tokens are not used as API authorization tokens
[ ] JWT signatures are verified
[ ] JWT issuer is verified
[ ] JWT token_use is verified
[ ] JWT client/audience is verified
[ ] Token expiration is verified
[ ] Required scopes are verified
[ ] Refresh-token lifetime is intentional
[ ] Refresh-token rotation is enabled where supported
[ ] Token revocation is enabled
[ ] Tokens are absent from logs
[ ] Passwordless and passkey options are evaluated
[ ] Passkey domain and RP ID are finalised
[ ] MFA mode is intentional
[ ] Recovery method does not conflict with MFA
[ ] TOTP is available for sensitive users
[ ] Federation attribute mappings are documented
[ ] Federated account-linking rules are secure
[ ] Tenant identity comes from trusted token claims
[ ] Resource-level authorization occurs in the backend
[ ] Groups are used only for coarse RBAC
[ ] Identity-pool guest access is disabled unless required
[ ] Identity-pool trust policies restrict aud and amr
[ ] Temporary credentials are least privilege
[ ] Lambda triggers are fast and idempotent
[ ] Lambda-trigger alarms exist
[ ] AWS WAF is evaluated
[ ] User-existence errors are suppressed
[ ] Threat protection is configured
[ ] Threat protection is tested in audit mode
[ ] Deletion protection is active
[ ] Terraform prevent_destroy is active
[ ] Cognito custom-domain certificate is in us-east-1
[ ] CloudTrail is enabled
[ ] Authentication metrics and alarms exist
[ ] User-pool quotas are reviewed
[ ] Login, MFA, reset and federation flows are load tested
[ ] Multi-Region eligibility is reviewed
[ ] Regional authentication failover is tested
```

---

# 146. Certification-focused understanding

## AWS Cloud Practitioner

Understand:

```text
Cognito user pool:
Application user directory

Cognito identity pool:
Temporary AWS credentials

Managed login:
Hosted authentication pages

MFA:
Additional authentication factor
```

## Solutions Architect Associate

Understand:

```text
User pools versus identity pools
Cognito federation
JWTs
Cognito groups
API Gateway authorizers
Temporary AWS credentials
Authenticated and guest roles
Social and enterprise identity providers
```

## DevOps Engineer Professional

Understand:

```text
OAuth authorization-code flow
PKCE
Client-credentials M2M
Custom resource-server scopes
Token rotation and revocation
Lambda triggers
Threat protection
Adaptive authentication
WAF
Multi-tenant claims
Identity-pool role mapping
Terraform replacement risk
Multi-Region replication
```

---

# 147. Interview questions

## Question 1: What is Amazon Cognito?

**Answer:**

Amazon Cognito is a managed identity service for authenticating application users, issuing tokens and optionally providing users with temporary AWS credentials.

## Question 2: What is the difference between user pools and identity pools?

**Answer:**

A user pool authenticates users and issues tokens. An identity pool exchanges a trusted identity for temporary AWS credentials associated with IAM roles.

## Question 3: What is an app client?

**Answer:**

It represents an application that authenticates against a user pool and defines settings such as OAuth grants, scopes, callback URLs, token lifetimes and client secrets.

## Question 4: Should a browser app client have a secret?

**Answer:**

No. Browser and mobile applications cannot securely protect a client secret and should use a public client with authorization code and PKCE.

## Question 5: What is PKCE?

**Answer:**

PKCE protects the authorization-code grant by requiring the token request to prove possession of a secret verifier associated with the original authorization request.

## Question 6: What is the difference between an ID token and access token?

**Answer:**

An ID token communicates authenticated identity information to the client. An access token carries scopes and authorization claims for protected APIs.

## Question 7: What is a refresh token?

**Answer:**

It is a long-lived session credential that obtains new access and ID tokens without requiring the user to authenticate again.

## Question 8: What is refresh-token rotation?

**Answer:**

It replaces the refresh token with a new refresh token whenever the session is renewed, reducing the reusable lifetime of stolen tokens.

## Question 9: What is managed login?

**Answer:**

It is Cognito’s managed authentication interface and OAuth/OIDC authorization service for sign-in, sign-up, MFA, passkeys, federation and password recovery.

## Question 10: Where must a Cognito custom-domain certificate exist?

**Answer:**

In ACM in `us-east-1`, regardless of the Region of the user pool.

## Question 11: What is a Cognito resource server?

**Answer:**

It represents a protected API and defines custom OAuth scopes such as `todo-api/todos.read`.

## Question 12: What is the client-credentials grant?

**Answer:**

It is a noninteractive OAuth grant where a confidential machine client exchanges its client ID and secret for an access token containing custom scopes.

## Question 13: What are Cognito groups?

**Answer:**

They are logical user classifications used for coarse role-based access control and optional identity-pool IAM-role selection.

## Question 14: What is adaptive authentication?

**Answer:**

It evaluates authentication risk from contextual and historical signals and can allow, challenge with MFA or block a sign-in.

## Question 15: What are Cognito Lambda triggers?

**Answer:**

They are Lambda functions invoked during user-pool events such as sign-up, authentication, token generation, messaging, federation and migration.

## Question 16: What is a pre-token generation trigger?

**Answer:**

It customizes claims, groups and scopes before Cognito issues ID or access tokens.

## Question 17: Why must API consumers validate `token_use`?

**Answer:**

It prevents an ID token from being accepted where an access token is required, or vice versa.

## Question 18: How does an identity pool give users AWS access?

**Answer:**

It validates the user’s identity token and obtains temporary credentials from AWS STS for an IAM role selected by the identity-pool configuration.

## Question 19: Does enabling MFA solve all identity security risks?

**Answer:**

No. You still need phishing-resistant factors, secure recovery, WAF, risk detection, token protection, least privilege and application-level authorization.

## Question 20: Why is replacing a Cognito user pool dangerous?

**Answer:**

The user pool contains the application’s user directory and authentication configuration. Replacement can disrupt every user and may not preserve passwords or identities automatically.

---

# 148. Never-forget revision

```text
User pool:
Authenticates application users.

Identity pool:
Provides temporary AWS credentials.

App client:
Application-specific authentication configuration.

Managed login:
Cognito-managed sign-in interface.

OAuth:
Delegated authorization.

OIDC:
Authentication identity layer.

Authorization code:
Safe interactive token flow.

PKCE:
Protects public-client authorization codes.

Client credentials:
Machine-to-machine authorization.

ID token:
Who signed in.

Access token:
What API access is allowed.

Refresh token:
Renew the session.

Scope:
Permitted API capability.

Resource server:
Protected API represented in Cognito.

Group:
Coarse user role.

Passkey:
WebAuthn public-key authentication.

MFA:
Additional authentication factor.

Federation:
Authenticate through another IdP.

Lambda trigger:
Customize a Cognito lifecycle event.

Threat protection:
Risk and compromise detection.

Identity-pool role:
Temporary AWS permission set.

Token revocation:
Invalidate a refresh-token session.

Multi-Region replication:
Regional authentication resilience.
```

## One-line memory trick

```text
Use a user pool to authenticate.
Use access tokens to authorize APIs.
Use an identity pool only for direct AWS access.
Use code plus PKCE for public clients.
Use client credentials for machines.
Use passkeys or MFA for stronger sign-in.
Trust validated claims, never client input.
```

## Lesson 54 outcome

You can now design identity where:

```text
A browser user signs in
    → Authorization code + PKCE protects the flow.

The application needs user identity
    → The ID token provides verified claims.

The API needs authorization
    → The access token provides scopes.

A background service calls an API
    → Client credentials provide an M2M token.

A user wants passwordless authentication
    → Email OTP, SMS OTP or passkeys are evaluated.

An enterprise uses Microsoft or Okta
    → OIDC or SAML federation connects the IdP.

A mobile user uploads directly to S3
    → An identity pool supplies temporary credentials.

An administrator needs elevated access
    → Groups and backend authorization enforce RBAC.

A suspicious sign-in occurs
    → Threat protection can challenge or block it.

A Region becomes unavailable
    → Eligible multi-Region user pools can continue authentication.
```

**Next lesson: Lesson 55 — AWS KMS, Secrets Manager, Systems Manager Parameter Store and ACM production cryptography and secrets architecture: envelope encryption, key policies, grants, rotation, secret retrieval, certificate lifecycle, cross-account access and incident recovery.**

[1]: https://docs.aws.amazon.com/cognito/latest/developerguide/what-is-amazon-cognito.html?utm_source=chatgpt.com "What is Amazon Cognito? - Amazon Cognito"
[2]: https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-pools.html?utm_source=chatgpt.com "Amazon Cognito user pools - Amazon Cognito"
[3]: https://docs.aws.amazon.com/cognito/latest/developerguide/identity-pools.html?utm_source=chatgpt.com "Identity pools console overview - Amazon Cognito"
[4]: https://docs.aws.amazon.com/cognito/latest/developerguide/token-endpoint.html?utm_source=chatgpt.com "The token issuer endpoint - Amazon Cognito"
[5]: https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-sign-in-feature-plans.html?utm_source=chatgpt.com "User pool feature plans - Amazon Cognito"
[6]: https://docs.aws.amazon.com/cognito/latest/developerguide/feature-plans-features-essentials.html?utm_source=chatgpt.com "Essentials plan features - Amazon Cognito"
[7]: https://docs.aws.amazon.com/cognito/latest/developerguide/user-pool-settings-client-apps.html?utm_source=chatgpt.com "Application-specific settings with app clients - Amazon Cognito"
[8]: https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-pools-assign-domain.html?utm_source=chatgpt.com "Configuring a user pool domain - Amazon Cognito"
[9]: https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-pools-managed-login.html?utm_source=chatgpt.com "User pool managed login - Amazon Cognito"
[10]: https://docs.aws.amazon.com/cognito/latest/developerguide/user-pool-security-best-practices.html?utm_source=chatgpt.com "Security best practices for Amazon Cognito user pools - Amazon Cognito"
[11]: https://docs.aws.amazon.com/cognito/latest/developerguide/managed-login-branding.html?utm_source=chatgpt.com "Apply branding to managed login pages - Amazon Cognito"
[12]: https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-pools-add-custom-domain.html?utm_source=chatgpt.com "Using your own domain for managed login - Amazon Cognito"
[13]: https://docs.aws.amazon.com/cognito/latest/developerguide/authorization-endpoint.html?utm_source=chatgpt.com "The redirect and authorization endpoint - Amazon Cognito"
[14]: https://docs.aws.amazon.com/cognito/latest/developerguide/using-pkce-in-authorization-code.html?utm_source=chatgpt.com "Using PKCE in authorization code grants - Amazon Cognito"
[15]: https://docs.aws.amazon.com/cognito/latest/developerguide/federation-endpoints-oauth-grants.html?utm_source=chatgpt.com "OAuth 2.0 grants - Amazon Cognito"
[16]: https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-pools-define-resource-servers.html?utm_source=chatgpt.com "Scopes, M2M, and resource servers - Amazon Cognito"
[17]: https://docs.aws.amazon.com/cognito/latest/developerguide/amazon-cognito-user-pools-using-the-refresh-token.html?utm_source=chatgpt.com "Refresh tokens - Amazon Cognito"
[18]: https://docs.aws.amazon.com/cognito-user-identity-pools/latest/APIReference/API_RefreshTokenRotationType.html?utm_source=chatgpt.com "RefreshTokenRotationType - Amazon Cognito User Pools"
[19]: https://docs.aws.amazon.com/cognito/latest/developerguide/amazon-cognito-user-pools-using-the-id-token.html?utm_source=chatgpt.com "Understanding the identity (ID) token - Amazon Cognito"
[20]: https://docs.aws.amazon.com/cognito/latest/developerguide/amazon-cognito-user-pools-using-the-access-token.html?utm_source=chatgpt.com "Understanding the access token - Amazon Cognito"
[21]: https://docs.aws.amazon.com/cognito/latest/developerguide/federation-endpoints.html?utm_source=chatgpt.com "Identity provider and relying party endpoints - Amazon Cognito"
[22]: https://docs.aws.amazon.com/cognito-user-identity-pools/latest/APIReference/API_TokenValidityUnitsType.html?utm_source=chatgpt.com "TokenValidityUnitsType - Amazon Cognito User Pools"
[23]: https://docs.aws.amazon.com/cognito/latest/developerguide/token-revocation.html?utm_source=chatgpt.com "Ending user sessions with token revocation - Amazon Cognito"
[24]: https://docs.aws.amazon.com/cognito/latest/developerguide/logout-endpoint.html?utm_source=chatgpt.com "The managed login sign-out endpoint: /logout"
[25]: https://docs.aws.amazon.com/cognito/latest/developerguide/amazon-cognito-user-pools-authentication-flow-methods.html?utm_source=chatgpt.com "Authentication flows - Amazon Cognito"
[26]: https://docs.aws.amazon.com/cognito/latest/developerguide/managing-security.html?utm_source=chatgpt.com "Using Amazon Cognito user pools security features"
[27]: https://docs.aws.amazon.com/cognito/latest/developerguide/user-pool-settings-mfa.html?utm_source=chatgpt.com "Adding MFA to a user pool - Amazon Cognito"
[28]: https://docs.aws.amazon.com/cognito/latest/developerguide/troubleshooting.html?utm_source=chatgpt.com "Troubleshoot Amazon Cognito - Amazon Cognito"
[29]: https://docs.aws.amazon.com/cognito/latest/developerguide/amazon-cognito-user-pools-device-tracking.html?utm_source=chatgpt.com "Working with user devices in your user pool - Amazon Cognito"
[30]: https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-pools-identity-federation.html?utm_source=chatgpt.com "User pool sign-in with third party identity providers - Amazon Cognito"
[31]: https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-pools-oidc-idp.html?utm_source=chatgpt.com "Using OIDC identity providers with a user pool - Amazon Cognito"
[32]: https://docs.aws.amazon.com/cognito/latest/developerguide/user-pool-lambda-inbound-federation.html?utm_source=chatgpt.com "Inbound federation Lambda trigger - Amazon Cognito"
[33]: https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-pools-user-groups.html?utm_source=chatgpt.com "Adding groups to a user pool - Amazon Cognito"
[34]: https://docs.aws.amazon.com/cognito/latest/developerguide/user-pool-lambda-pre-token-generation.html?utm_source=chatgpt.com "Pre token generation Lambda trigger - Amazon Cognito"
[35]: https://docs.aws.amazon.com/cognito/latest/developerguide/authentication-flow.html?utm_source=chatgpt.com "Identity pools authentication flow - Amazon Cognito"
[36]: https://docs.aws.amazon.com/cognito/latest/developerguide/role-based-access-control.html?utm_source=chatgpt.com "Using role-based access control - Amazon Cognito"
[37]: https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-pools-working-with-lambda-triggers.html?utm_source=chatgpt.com "Customizing user pool workflows with Lambda triggers - Amazon Cognito"
[38]: https://docs.aws.amazon.com/cognito/latest/developerguide/multi-tenant-application-best-practices.html?utm_source=chatgpt.com "Multi-tenant application best practices - Amazon Cognito"
[39]: https://docs.aws.amazon.com/cognito/latest/developerguide/user-pool-lambda-challenge.html?utm_source=chatgpt.com "Custom authentication challenge Lambda triggers - Amazon Cognito"
[40]: https://docs.aws.amazon.com/cognito/latest/developerguide/federation-endpoint-idp-responses.html?utm_source=chatgpt.com "Managed login and federation error responses - Amazon Cognito"
[41]: https://docs.aws.amazon.com/cognito/latest/developerguide/user-pool-waf.html?utm_source=chatgpt.com "Associate an AWS WAF web ACL with a user pool - Amazon Cognito"
[42]: https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-pool-settings-compromised-credentials.html?utm_source=chatgpt.com "Working with compromised-credentials detection"
[43]: https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-pool-settings-adaptive-authentication.html?utm_source=chatgpt.com "Working with adaptive authentication - Amazon Cognito"
[44]: https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-pool-settings-threat-protection.html?utm_source=chatgpt.com "Advanced security with threat protection - Amazon Cognito"
[45]: https://docs.aws.amazon.com/cognito/latest/developerguide/bp_user-pool-based-multi-tenancy.html?utm_source=chatgpt.com "User-pool multi-tenancy best practices - Amazon Cognito"
[46]: https://docs.aws.amazon.com/cognito/latest/developerguide/security-cognito-regional-data-considerations.html?utm_source=chatgpt.com "Regional data considerations - Amazon Cognito"
[47]: https://docs.aws.amazon.com/cognito/latest/developerguide/user-pool-multi-region.html?utm_source=chatgpt.com "Multi-Region replication for user pools - Amazon Cognito"
[48]: https://docs.aws.amazon.com/cognito/latest/developerguide/logging-using-cloudtrail.html?utm_source=chatgpt.com "Amazon Cognito logging in AWS CloudTrail - Amazon Cognito"
[49]: https://docs.aws.amazon.com/cognito/latest/developerguide/metrics-for-cognito-user-pools.html?utm_source=chatgpt.com "User pool metrics in CloudWatch - Amazon Cognito"
[50]: https://registry.terraform.io/providers/hashicorp/aws/6.0.0/docs/resources/cognito_user_pool?utm_source=chatgpt.com "aws_cognito_user_pool | Resources | hashicorp/aws | Terraform | Terraform Registry"
[51]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_user_pool_client?utm_source=chatgpt.com "aws_cognito_user_pool_client | Resources | hashicorp/aws | Terraform | Terraform Registry"
[52]: https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-pools-assign-domain-prefix.html?utm_source=chatgpt.com "Using the Amazon Cognito prefix domain for managed login - Amazon Cognito"
[53]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_user_group?utm_source=chatgpt.com "aws_cognito_user_group | Resources | hashicorp/aws | Terraform | Terraform Registry"
[54]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_identity_provider.html?utm_source=chatgpt.com "aws_cognito_identity_provider | Resources | hashicorp/aws | Terraform | Terraform Registry"
[55]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_identity_pool?utm_source=chatgpt.com "aws_cognito_identity_pool | Resources | hashicorp/aws | Terraform | Terraform Registry"
[56]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_identity_pool_roles_attachment?utm_source=chatgpt.com "aws_cognito_identity_pool_roles_attachment | Resources | hashicorp/aws | Terraform | Terraform Registry"
