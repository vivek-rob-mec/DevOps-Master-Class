# AWS Masterclass — Lesson 29 Part 4

# Route 53 Security, DNSSEC, Migration, Terraform & Production DNS Capstone

This is the final Route 53 lesson.

So far:

```text
Lesson 29 Part 1
DNS fundamentals
A / AAAA / CNAME / Alias
Hosted zones
TTL

Lesson 29 Part 2
Routing policies
Health checks
Multi-Region failover

Lesson 29 Part 3
Private DNS
VPC Resolver
Hybrid DNS
DNS Firewall
Query logging

Lesson 29 Part 4
             ↓
DNS SECURITY
DNSSEC
MIGRATION
IAM
OPERATIONS
TROUBLESHOOTING
PRODUCTION CAPSTONE
```

After this, **Lesson 29 is complete** and we move to **Lesson 30 — AWS IAM & Enterprise Security Architecture**.

---

# 1. What Problem Does DNSSEC Solve?

Normal DNS asks:

```text
Client:
"What is api.example.com?"

DNS:
"203.0.113.50"
```

But traditional DNS by itself wasn't designed to cryptographically prove:

> “This answer is authentic and hasn't been modified.”

An attacker who can manipulate DNS information might attempt:

```text
User
 │
 ▼
api.example.com
 │
 ▼
FAKE DNS ANSWER
 │
 ▼
Attacker-controlled server
```

DNSSEC adds cryptographic signatures so DNSSEC-validating resolvers can verify that signed DNS data is authentic and hasn't been altered in transit. Route 53 supports DNSSEC signing for public hosted zones. ([AWS Documentation][1])

---

# 2. DNSSEC Does NOT Encrypt DNS

Very important.

DNSSEC provides:

```text
AUTHENTICITY
+
INTEGRITY
```

It does **not** provide:

```text
CONFIDENTIALITY
```

DNSSEC does not turn:

```text
api.example.com
```

into secret information.

Think:

```text
TLS
=
encrypts application connection

DNSSEC
=
cryptographically validates DNS data
```

Do not confuse:

```text
DNSSEC
```

with:

```text
DNS-over-HTTPS
DNS-over-TLS
TLS/HTTPS
```

They solve different problems.

---

# 3. The DNSSEC Chain of Trust

The key concept is:

# Chain of Trust

Suppose we're protecting:

```text
yourdatascientist.tech
```

Conceptually:

```text
                    DNS ROOT
                       │
                 trusts/signs
                       ▼
                     .tech
                       │
                 DS relationship
                       ▼
          yourdatascientist.tech
                       │
                     DNSKEY
                       │
                       ▼
              signed DNS records
```

The resolver can validate from a trusted parent down toward your signed zone.

Route 53 requires you to enable zone signing and then establish the parent-child trust relationship with a **Delegation Signer (DS) record**. ([AWS Documentation][2])

---

# 4. DNSSEC Uses Two Key Roles

You need to know:

```text
KSK
=
Key Signing Key
```

and:

```text
ZSK
=
Zone Signing Key
```

Conceptually:

```text
                    KSK
                     │
                     ▼
                 signs DNSKEY
                     │
                     ▼
                    ZSK
                     │
                     ▼
             signs zone records
```

In Route 53, you manage the KSK relationship, while Route 53 manages the ZSK lifecycle for the hosted zone. ([AWS Documentation][1])

---

# 5. KSK — Key Signing Key

The KSK establishes the cryptographic identity of the zone.

Route 53 backs a KSK using:

```text
AWS KMS
customer-managed asymmetric key
```

Architecture:

```text
Route 53 Hosted Zone
       │
       ▼
      KSK
       │
       ▼
AWS KMS customer-managed key
```

AWS currently allows up to **two KSKs per hosted zone**, which helps with controlled KSK rollover. ([AWS Documentation][3])

---

# 6. ZSK — Zone Signing Key

The ZSK signs zone data.

Route 53 manages it for you.

Current Route 53 behavior uses an active ZSK for each signed hosted zone and automatically performs ZSK rotation. AWS currently describes regular rotation occurring roughly every **7–30 days**, although AWS notes the internal practice can evolve. ([AWS Documentation][4])

So:

```text
KSK
=
you manage its KMS-backed lifecycle

ZSK
=
Route 53 manages
```

---

# 7. Why KMS Is Involved

When Route 53 needs to generate the relevant DNSSEC signature for the DNSKEY record set:

```text
Route 53
    │
    ▼
AWS KMS Sign
    │
    ▼
KSK signature
```

Route 53 calls AWS KMS using the customer-managed key associated with the KSK. ([AWS Documentation][4])

This creates a critical dependency:

```text
DNSSEC
   │
   ▼
KSK
   │
   ▼
KMS key availability + policy
```

Therefore a bad KMS change can become a DNS availability incident.

---

# 8. DNSSEC KMS Region — Important

Route 53 is global.

But the KMS key used for Route 53 DNSSEC signing must currently exist in:

```text
us-east-1
```

US East (N. Virginia). ([AWS Documentation][5])

This should sound familiar.

We already encountered another global service with a similar regional requirement:

```text
CloudFront ACM certificate
→ us-east-1
```

But remember these are different systems:

```text
CloudFront certificate
→ ACM us-east-1

Route 53 DNSSEC KSK
→ KMS us-east-1
```

---

# 9. DNSSEC KMS Key Type

AWS currently requires the DNSSEC KSK's KMS key to be:

```text
Customer managed

Asymmetric

Key spec:
ECC_NIST_P256

Usage:
SIGN_VERIFY
```

and located in:

```text
us-east-1
```

for Route 53 DNSSEC signing. ([AWS Documentation][5])

### Never forget

```text
Route 53 DNSSEC KMS:

Region     = us-east-1
Type       = asymmetric
Key spec   = ECC_NIST_P256
Usage      = SIGN_VERIFY
```

---

# 10. Why Destroying That KMS Key Is Dangerous

Imagine:

```text
yourdatascientist.tech
     │
     ▼
DNSSEC KSK
     │
     ▼
KMS Key
```

Someone changes the KMS policy:

```text
Route 53 no longer allowed to Sign()
```

or schedules/removes the underlying key.

Then KSK state can become:

```text
ACTION_NEEDED
```

AWS warns this is serious because once previously generated signatures expire, validating resolvers can begin failing DNS lookups for the zone. ([AWS Documentation][6])

Potential user experience:

```text
User
 │
 ▼
DNSSEC validating resolver
 │
 ▼
cannot validate signed zone
 │
 ▼
SERVFAIL
```

That can look like:

> “The whole website disappeared.”

while:

```text
CloudFront = healthy
ALB = healthy
EC2 = healthy
database = healthy
```

The root cause is DNSSEC/KMS.

---

# 11. Monitor DNSSEC

AWS strongly recommends alarms for:

```text
DNSSECInternalFailure
```

and:

```text
DNSSECKeySigningKeysNeedingAction
```

Route 53 publishes these hosted-zone metrics in the:

```text
AWS/Route53
```

CloudWatch namespace. Because Route 53 is global, these hosted-zone metrics are retrieved in the `us-east-1` CloudWatch Region context. ([AWS Documentation][7])

Architecture:

```text
Route 53 DNSSEC
      │
      ▼
CloudWatch
      │
      ▼
Alarm
      │
      ▼
SNS / Incident Management
```

DNSSEC without monitoring is not a mature production design.

---

# 12. DNSSEC Signing Flow

Simplified:

```text
Resource record

api.example.com
A
203.0.113.10

        │
        ▼
Route 53 signs DNS data
        │
        ▼
RRSIG
        │
        ▼
DNSSEC-validating resolver
        │
        ▼
cryptographic verification
```

Then the resolver can answer:

```text
VALID
```

or reject invalid DNS data.

---

# 13. What Is an RRSIG?

RRSIG is essentially:

```text
DNS resource-record signature
```

For a signed zone, Route 53 provides signatures that validators use to verify DNS record sets.

Conceptually:

```text
A record
+
signature
```

```text
AAAA record
+
signature
```

```text
MX record
+
signature
```

and so forth.

You don't manually sign every A record yourself.

Route 53 handles zone signing once DNSSEC is configured. ([AWS Documentation][1])

---

# 14. DNSKEY

A signed zone publishes:

```text
DNSKEY
```

records containing public DNSSEC key information.

The validating resolver needs to know:

```text
Can I trust this DNSKEY?
```

That's where:

```text
parent zone
+
DS record
```

come in.

---

# 15. DS — Delegation Signer

The parent zone publishes a DS record representing cryptographic information associated with the child zone's key.

Conceptually:

```text
.tech
 │
 │ DS says:
 │ "This is the trusted signing identity
 │  for yourdatascientist.tech"
 │
 ▼
yourdatascientist.tech
```

Without the DS relationship in the parent:

```text
zone can be signed
```

but:

```text
public chain of trust
is incomplete
```

Route 53 explicitly separates:

```text
Enable zone signing
```

from:

```text
Establish chain of trust
with DS
```

as separate steps. ([AWS Documentation][2])

---

# 16. DNSSEC Enablement Order

Do **not** randomly add the DS first.

A safer conceptual order is:

```text
1. Prepare TTL/monitoring

2. Create KMS key

3. Create KSK

4. Enable hosted-zone DNSSEC signing

5. Verify Route 53 is serving signed responses

6. Allow old unsigned cache data to age out

7. Add DS information at registrar/parent

8. Verify chain of trust

9. Monitor
```

AWS's current DNSSEC onboarding procedure follows this signing-first, trust-establishment-afterward approach to minimize outage risk. ([AWS Documentation][2])

---

# 17. Why DS-First Is Dangerous

Suppose the parent says:

```text
yourdatascientist.tech
MUST be DNSSEC signed
```

because the DS exists.

But your child zone isn't correctly serving valid DNSSEC data.

A validating resolver sees:

```text
DS exists
       │
       ▼
validation required
       │
       ▼
signature missing/broken
       │
       ▼
BOGUS
       │
       ▼
SERVFAIL
```

You can effectively make your domain unreachable for DNSSEC-validating clients.

---

# 18. DNSSEC Is Security With Operational Risk

Think of DNSSEC as:

```text
SECURITY
+
CRYPTOGRAPHIC DEPENDENCY
+
STRICT CONFIGURATION
```

A badly configured unsigned domain may still resolve.

A badly configured **signed** domain may fail validation entirely.

That's why production DNSSEC requires:

```text
change management
monitoring
KMS protection
DS lifecycle management
rollback planning
```

---

# 19. Prepare TTL Before Enabling DNSSEC

Current AWS guidance recommends lowering the zone's maximum TTL before onboarding DNSSEC to reduce rollback waiting time.

AWS's current DNSSEC enablement procedure recommends temporarily reducing the maximum zone TTL to around:

```text
3600 seconds
```

during preparation. ([AWS Documentation][2])

Why?

If something fails:

```text
smaller caches
→ quicker rollback
```

This is the same operational principle we learned during ordinary DNS migrations.

---

# 20. DNSSEC TTL Limitation

Once DNSSEC signing is enabled, Route 53 currently enforces a maximum effective TTL of:

```text
1 week
```

for records in that signed hosted zone.

Even if you configure a higher value, Route 53 enforces the one-week maximum for signed-zone responses. ([AWS Documentation][1])

This is an excellent example of why current AWS behavior must be checked rather than relying on old notes.

---

# 21. Check DNSSEC With `dig`

Basic:

```bash
dig yourdatascientist.tech
```

DNSSEC-aware query:

```bash
dig +dnssec yourdatascientist.tech
```

Check DNSKEY:

```bash
dig +dnssec DNSKEY yourdatascientist.tech
```

Check parent DS:

```bash
dig +dnssec DS yourdatascientist.tech
```

The goal is to reason through:

```text
Parent DS
   │
   ▼
Child DNSKEY
   │
   ▼
signed resource records
```

---

# 22. `ad` Flag

When using a DNSSEC-validating recursive resolver, a successful validated response may include:

```text
ad
```

meaning:

```text
Authenticated Data
```

in the DNS response flags.

Conceptually:

```text
;; flags: qr rd ra ad;
```

The presence depends on resolver behavior and whether it performed validation.

Do not confuse:

```text
DNSSEC data returned
```

with:

```text
your local resolver actually validated it.
```

---

# 23. DNSSEC Failure Symptom: `SERVFAIL`

Suppose:

```bash
dig api.example.com
```

returns:

```text
SERVFAIL
```

Potential DNSSEC causes include:

```text
bad DS
KSK problem
KMS access failure
expired/invalid signatures
incorrect chain of trust
```

AWS specifically warns that DNSSEC failures can make signed zones unresolvable through validating resolvers. ([AWS Documentation][6])

But `SERVFAIL` can have other DNS causes too, so don't assume DNSSEC immediately.

---

# 24. Safe DNSSEC Disablement Is Reverse Order

Suppose you no longer want DNSSEC.

The dangerous action is:

```text
Disable signing immediately
while parent DS remains active.
```

Then:

```text
Parent:
"DNSSEC validation required"

Child:
"no valid signing"
```

Result:

```text
SERVFAIL
```

AWS's documented process requires removing the trust relationship first, waiting for DS TTL/cache effects to expire, and only then disabling zone signing. ([AWS Documentation][8])

Conceptually:

```text
1. Remove DS from parent

2. Wait required TTL

3. Verify DS gone

4. Disable DNSSEC signing

5. Deactivate/delete KSK as appropriate
```

---

# 25. Never-Forget DNSSEC Ordering

### Enable

```text
SIGN CHILD
    ↓
VERIFY
    ↓
ADD PARENT DS
```

### Disable

```text
REMOVE PARENT DS
    ↓
WAIT
    ↓
DISABLE CHILD SIGNING
```

This one ordering rule can prevent an entire DNS outage.

---

# 26. Terraform DNSSEC Architecture

We need:

```text
Route 53 Hosted Zone

       │
       ▼

KMS key
us-east-1

       │
       ▼

Route 53 KSK

       │
       ▼

Hosted Zone DNSSEC
```

The current HashiCorp AWS provider uses:

```text
aws_route53_key_signing_key
```

and:

```text
aws_route53_hosted_zone_dnssec
```

for these components. ([Terraform Registry][9])

---

# 27. Terraform Provider Layout

Suppose most infrastructure lives in:

```text
ap-south-1
```

but DNSSEC KMS must be:

```text
us-east-1
```

Use an aliased provider:

```hcl
provider "aws" {
  region = "ap-south-1"
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}
```

This is the same provider-alias pattern we use for CloudFront ACM.

---

# 28. Terraform DNSSEC KMS Key

Conceptually:

```hcl
resource "aws_kms_key" "route53_dnssec" {
  provider = aws.us_east_1

  description = "Route 53 DNSSEC KSK"

  key_usage = "SIGN_VERIFY"

  customer_master_key_spec = "ECC_NIST_P256"

  deletion_window_in_days = 30
}
```

Current Route 53 requires that asymmetric P-256 signing key in `us-east-1`. ([AWS Documentation][5])

In production, the KMS key policy must explicitly permit Route 53 DNSSEC to perform the required signing/key operations; do not use an unreviewed broad KMS policy merely to make deployment succeed. ([AWS Documentation][5])

---

# 29. Terraform KSK

Conceptually:

```hcl
resource "aws_route53_key_signing_key" "main" {
  hosted_zone_id = aws_route53_zone.public.id

  key_management_service_arn =
    aws_kms_key.route53_dnssec.arn

  name = "main_ksk"

  status = "ACTIVE"
}
```

The KSK resource connects:

```text
Route 53 hosted zone
```

to:

```text
KMS asymmetric signing key
```

through Terraform. ([Terraform Registry][9])

---

# 30. Terraform Enable DNSSEC

```hcl
resource "aws_route53_hosted_zone_dnssec" "main" {
  depends_on = [
    aws_route53_key_signing_key.main
  ]

  hosted_zone_id =
    aws_route53_key_signing_key.main.hosted_zone_id
}
```

Now the zone becomes DNSSEC signed.

But this alone does **not** necessarily complete:

```text
Parent DS
```

registration.

You still need to establish the chain of trust at the parent/registrar. ([AWS Documentation][2])

---

# 31. DNSSEC Infrastructure vs Domain Registration

These are separate layers:

```text
Route 53 hosted zone
      │
      ▼
DNSSEC signing
```

versus:

```text
Registrar / parent zone
      │
      ▼
DS record
```

If the domain registrar is outside Route 53:

```text
you may need to add DNSSEC/DS data
through that registrar's interface.
```

Route 53 gives you the required DS information after signing is enabled. ([AWS Documentation][2])

---

# 32. Domain Security — Transfer Lock

If your domain is registered with Route 53, you can enable a **domain transfer lock** to help prevent unauthorized transfer to another registrar.

Registrars commonly use transfer locks as a security control. ([AWS Documentation][10])

Think:

```text
Domain
   │
   ▼
Transfer lock ON
   │
   X
unauthorized registrar transfer
```

For an important production domain:

```text
transfer lock
=
normally desirable
```

except when intentionally preparing a legitimate registrar transfer.

---

# 33. Domain Security Is Bigger Than DNSSEC

Protect:

```text
1. AWS root/admin access

2. Registrar access

3. Route 53 hosted-zone changes

4. Domain contact ownership

5. Transfer lock

6. KMS DNSSEC keys

7. CI/CD Route 53 permissions

8. Terraform state

9. MFA

10. Change auditing
```

Why?

Because someone who can change:

```text
api.example.com
```

may be able to redirect users to infrastructure they control.

DNS is a high-value security control plane.

---

# 34. IAM Least Privilege for Route 53

A common anti-pattern:

```json
{
  "Effect": "Allow",
  "Action": "route53:*",
  "Resource": "*"
}
```

given to every deployment system.

Instead, Route 53 supports fine-grained controls over record changes, including IAM condition keys that restrict updates by:

```text
record name
record type
record action
```

AWS documents these controls specifically for `ChangeResourceRecordSets`. ([AWS Documentation][11])

---

# 35. Example Security Requirement

A frontend CI/CD pipeline should be allowed to modify only:

```text
preview.example.com
```

and perhaps only:

```text
A
AAAA
```

records.

It should **not** be able to modify:

```text
MX
```

for company email,

```text
NS
```

for delegation,

or:

```text
prod-api.example.com
```

Fine-grained Route 53 record permissions can enforce this style of boundary. ([AWS Documentation][12])

---

# 36. Why DNS Permissions Are So Sensitive

Imagine compromised CI runner:

```text
Attacker
   │
   ▼
CI Role
   │
   ▼
Route53:ChangeResourceRecordSets
   │
   ▼
api.example.com
   │
   ▼
attacker endpoint
```

Even if:

```text
EC2 IAM
RDS IAM
VPC security
```

are perfect, users may now resolve the wrong application endpoint.

DNS administration belongs in your privileged-access model.

---

# 37. Route 53 Changes Are Transactional

The `ChangeResourceRecordSets` API lets you submit batches of DNS changes.

AWS treats changes in a batch transactionally:

```text
all changes
```

or:

```text
none
```

if validation fails.

The API is used to create, update, and delete authoritative Route 53 records. ([AWS Documentation][13])

This matters when deploying related DNS records together.

---

# 38. DNS Change Auditing

Route 53 configuration API calls should be captured through:

```text
AWS CloudTrail
```

so security teams can answer:

```text
Who changed api.example.com?

When?

Which IAM principal?

Which API call?

From where?
```

We'll cover CloudTrail deeply later, but for now your architecture should assume:

```text
DNS changes
=
auditable security events.
```

---

# 39. Public DNS Query Visibility vs VPC Resolver Query Logs

Do not mix these concepts.

### Public authoritative Route 53

Concern:

```text
Who is querying my public hosted zone?
```

### VPC Resolver query logging

Concern:

```text
What DNS names are my VPC workloads asking for?
```

They operate at different DNS layers.

Part 3's Resolver query logging was:

```text
EC2/ECS/Lambda
     │
     ▼
VPC Resolver queries
```

not simply your public hosted-zone traffic.

---

# 40. DNS Migration Scenario

Suppose your domain currently uses:

```text
Old DNS Provider
```

and you want:

```text
Amazon Route 53
```

The dangerous migration is:

```text
1. Change registrar NS to Route 53

2. Then start copying records
```

because the new authoritative service might become active without having the correct records.

Safer strategy:

```text
PREPARE ROUTE 53 FIRST

THEN SWITCH DELEGATION
```

AWS's migration guidance follows this pattern. ([AWS Documentation][14])

---

# 41. Safe Migration Workflow

```text
CURRENT

Registrar
   │
   ▼
Old DNS
   │
   ▼
production records
```

Prepare:

```text
Old DNS                 Route 53
   │                       │
production records     copied records
```

Then change registrar delegation:

```text
Registrar
   │
   ▼
Route 53 NS
```

Only after Route 53 is ready.

---

# 42. Step 1 — Inventory Existing DNS

Before migration, export/list:

```text
A
AAAA
CNAME
MX
TXT
CAA
SRV
NS delegations
verification records
DKIM
SPF
DMARC
ACM validation
third-party SaaS records
```

Do not migrate only:

```text
www
api
```

and accidentally break:

```text
company email.
```

DNS zones commonly contain infrastructure you didn't realize depended on them.

---

# 43. Step 2 — Lower TTL Before Migration

If the current DNS has:

```text
TTL = 86400
```

and you switch tomorrow, resolvers may retain old data for:

```text
up to 24 hours
```

depending on when they cached it.

So you lower TTL **before** migration.

AWS's current DNS migration guidance recommends using a short TTL during migration, generally in the range of roughly **60–900 seconds** for the migration preparation. ([AWS Documentation][14])

Example:

```text
OLD:

api.example.com
TTL = 86400


PRE-MIGRATION:

api.example.com
TTL = 300
```

Then wait long enough for the **old** TTL to expire before relying on the new short TTL.

---

# 44. Why Lowering TTL at the Last Second Doesn't Help

Suppose:

```text
Monday
TTL = 86400
```

Resolver caches Monday's record.

At:

```text
Tuesday 10:00
```

you change TTL to:

```text
300
```

That resolver might still have the **old record with the old 86400 TTL**.

So planned migration is:

```text
lower TTL
   │
   ▼
WAIT original TTL
   │
   ▼
perform migration
```

This is an important production concept.

---

# 45. Step 3 — Create Route 53 Hosted Zone

Create:

```text
Public Hosted Zone

example.com
```

Route 53 automatically assigns its authoritative:

```text
NS
```

and:

```text
SOA
```

records. ([AWS Documentation][15])

Do **not** assume these name servers match some previously created hosted zone.

Every independently created hosted zone gets its own delegation set.

---

# 46. Duplicate Hosted Zones Trap

Suppose you accidentally have:

```text
Hosted Zone A
example.com

Hosted Zone B
example.com
```

AWS allows separate hosted zones with the same domain name.

But the internet uses only the zone referenced by the registrar's active NS delegation.

If you edit Zone B while registrar points to Zone A:

```text
nothing changes for users.
```

Always verify:

```bash
dig NS example.com
```

against the hosted zone you're modifying.

---

# 47. Step 4 — Copy All Records

Create equivalent records in Route 53.

Verify using:

```bash
aws route53 list-resource-record-sets \
  --hosted-zone-id "$ZONE_ID"
```

Then query one of Route 53's assigned authoritative servers directly:

```bash
dig @ns-xxxx.awsdns-xx.org example.com A

dig @ns-xxxx.awsdns-xx.org www.example.com A

dig @ns-xxxx.awsdns-xx.org example.com MX

dig @ns-xxxx.awsdns-xx.org example.com TXT
```

This tests Route 53 **before** it becomes globally authoritative.

That is an excellent migration technique.

---

# 48. Step 5 — Compare Old vs New DNS

Conceptually:

```text
OLD DNS                ROUTE 53

A         ✓             A         ✓
AAAA      ✓             AAAA      ✓
MX        ✓             MX        ✓
TXT       ✓             TXT       ✓
CAA       ✓             CAA       ✓
DKIM      ✓             DKIM      ✓
DMARC     ✓             DMARC     ✓
```

Do not switch NS until the important responses match your intended migration state.

---

# 49. Step 6 — Change Registrar Name Servers

Now update the registrar:

```text
OLD:

ns1.old-provider.com
ns2.old-provider.com
```

to the Route 53 NS set.

Example conceptually:

```text
ns-xxx.awsdns-xx.com
ns-xxx.awsdns-xx.net
ns-xxx.awsdns-xx.org
ns-xxx.awsdns-xx.co.uk
```

This changes the DNS delegation.

AWS notes that name-server delegation changes can remain cached by resolvers for a long period—potentially up to roughly two days depending on NS TTL/cache state. ([AWS Documentation][16])

---

# 50. During Migration Both Providers May Receive Traffic

During the transition:

```text
Resolver A
cached old NS
    │
    ▼
Old DNS


Resolver B
refreshed NS
    │
    ▼
Route 53
```

Therefore keep:

```text
OLD DNS
```

alive and consistent during the transition.

Do **not** immediately delete the old DNS zone after changing registrar name servers.

---

# 51. Low-Downtime Migration Principle

During delegation transition:

```text
Old DNS
and
Route 53
```

should ideally both answer:

```text
VALID PRODUCTION DATA
```

Then regardless of which name-server delegation a resolver currently has:

```text
application still works.
```

That is how you minimize DNS migration downtime.

---

# 52. DNSSEC Makes DNS Migration More Sensitive

If the old provider uses DNSSEC:

```text
Parent DS
   │
   ▼
old provider signing keys
```

and you simply switch authoritative nameservers to Route 53 without correctly migrating DNSSEC trust:

```text
validation can break.
```

DNSSEC migration needs deliberate:

```text
signing-key strategy
DS update/removal
TTL waits
chain-of-trust validation
```

Never treat a DNSSEC-signed domain exactly like an unsigned DNS migration.

---

# 53. Migration Validation Commands

### Delegation

```bash
dig NS yourdatascientist.tech
```

### Trace

```bash
dig +trace yourdatascientist.tech
```

### IPv4

```bash
dig A yourdatascientist.tech
```

### IPv6

```bash
dig AAAA yourdatascientist.tech
```

### Website

```bash
dig www.yourdatascientist.tech
```

### Email

```bash
dig MX yourdatascientist.tech
```

### TXT

```bash
dig TXT yourdatascientist.tech
```

### DNSSEC

```bash
dig +dnssec DNSKEY yourdatascientist.tech

dig +dnssec DS yourdatascientist.tech
```

---

# 54. Production DNS Troubleshooting — Master Flow

Start:

```text
                   USER REPORT
                  "SITE IS DOWN"
                        │
                        ▼
                  DOES DNS RESOLVE?
                        │
             ┌──────────┴──────────┐
            NO                    YES
             │                     │
             ▼                     ▼
          DNS path          application/network
```

If DNS fails:

```text
1. NS delegation?

2. authoritative servers?

3. record exists?

4. correct type?

5. TTL/cache?

6. NXDOMAIN?

7. DNSSEC?

8. private/public zone conflict?

9. Resolver rule?

10. DNS Firewall?

11. hybrid endpoint?

12. registrar issue?
```

Do not jump randomly between layers.

---

# 55. `NXDOMAIN`

Means roughly:

```text
The queried DNS name
does not exist
```

Check:

```text
record spelling
hosted-zone ownership
private zone
delegation
negative cache
```

Remember that a private hosted zone owning the namespace can produce NXDOMAIN rather than falling through to the public zone. That behavior was covered in Part 3.

---

# 56. `SERVFAIL`

`SERVFAIL` means the resolver could not successfully complete resolution.

Possible causes:

```text
DNSSEC validation failure

authoritative server problem

broken delegation

resolver forwarding failure

DNS loop

upstream DNS problem
```

With a DNSSEC-signed zone:

```text
SERVFAIL
```

should immediately make you investigate:

```text
DS
DNSKEY
RRSIG
KSK
KMS
```

in addition to normal DNS resolution.

---

# 57. `REFUSED`

A DNS server can return:

```text
REFUSED
```

when it intentionally declines to answer the query.

Possible:

```text
resolver access policy
DNS server ACL
server not willing to recurse
wrong server queried
```

This differs from:

```text
NXDOMAIN
```

which means the name doesn't exist.

---

# 58. DNS Timeout

If:

```bash
dig name.example.com
```

just times out, think network path:

```text
UDP 53 blocked?

TCP 53 blocked?

resolver endpoint SG?

firewall?

VPN?

Direct Connect?

NACL?

on-prem DNS reachable?
```

Timeout is fundamentally different from receiving:

```text
NXDOMAIN
```

or:

```text
SERVFAIL
```

because in those cases a DNS server actually responded.

---

# 59. DNS Troubleshooting Error Mapping

```text
NXDOMAIN
=
name doesn't exist
or private namespace says it doesn't


SERVFAIL
=
resolver couldn't validate/complete resolution


REFUSED
=
DNS server declined query


TIMEOUT
=
no useful DNS response returned in time


NOERROR + wrong answer
=
record / caching / routing-policy problem
```

This is a very useful mental model.

---

# 60. Stale Answer Troubleshooting

User gets:

```text
old IP
```

Authoritative Route 53 returns:

```text
new IP
```

Then:

```text
Route 53 = correct
```

Likely:

```text
recursive resolver cache
client cache
browser cache
```

Check TTL:

```bash
dig api.example.com
```

Compare with authoritative server:

```bash
dig @<authoritative-ns> api.example.com
```

---

# 61. Wrong NS Troubleshooting

Run:

```bash
dig NS example.com
```

Then compare with:

```bash
aws route53 get-hosted-zone \
  --id "$ZONE_ID"
```

or inspect the zone's NS record.

If they differ:

```text
Registrar delegation
       │
       ▼
not pointing at the Route 53 zone
you're editing
```

Fix delegation rather than application resources.

---

# 62. `dig +trace` — Your DNS X-Ray

```bash
dig +trace api.example.com
```

Conceptually shows:

```text
ROOT
 │
 ▼
TLD
 │
 ▼
delegation
 │
 ▼
authoritative servers
 │
 ▼
record
```

This is extremely powerful for:

```text
bad NS

missing delegation

subdomain delegation problems

DNSSEC chain issues
```

---

# 63. Subdomain Delegation

You can split DNS authority.

Example:

```text
example.com
```

hosted in one system.

But:

```text
dev.example.com
```

delegated to another hosted zone.

Parent:

```text
example.com

NS dev.example.com
→ dev-zone authoritative servers
```

Then:

```text
dev.example.com
```

can be independently managed.

This is useful for:

```text
environment delegation
team ownership
multi-account architecture
```

but creates another chain of NS delegation that must be correct.

---

# 64. Do Not Create CNAME at Apex

Still remember from Part 1:

```text
example.com
```

cannot normally use standard:

```text
CNAME
```

because apex needs other records such as:

```text
NS
SOA
```

For supported AWS targets:

```text
Route 53 Alias
```

solves this cleanly.

---

# 65. Production Static Website DNS

Modern recommended pattern:

```text
User
 │
 ▼
yourdatascientist.tech
 │
 ▼
Route 53
 │
 │ Alias A/AAAA
 ▼
CloudFront
 │
 │ HTTPS
 ▼
Private S3
   OAC
```

Key security properties:

```text
S3 public access blocked

CloudFront public

OAC to S3

ACM certificate in us-east-1

Route 53 Alias
```

DNS remains only one layer of that architecture.

---

# 66. Production API DNS

```text
api.yourdatascientist.tech
        │
        ▼
     Route 53
        │
       Alias
        ▼
       ALB
        │
    HTTPS listener
        │
        ▼
  target groups / ASG
```

Route 53 handles:

```text
name → ALB
```

ALB handles:

```text
HTTP routing
TLS
health
backend selection
```

Do not confuse their responsibilities.

---

# 67. Multi-Region DR DNS

Let's build:

```text
Mumbai
=
PRIMARY

Singapore
=
SECONDARY
```

Architecture:

```text
                        api.example.com
                              │
                              ▼
                           Route 53
                        Failover Policy
                              │
                ┌─────────────┴─────────────┐
                ▼                           ▼
          PRIMARY                         SECONDARY
        ap-south-1                     ap-southeast-1
            │                               │
           ALB                             ALB
            │                               │
           ASG                             ASG
            │                               │
          Aurora ───── DR/Global DB ───── Secondary
```

Route 53 decides regional endpoint.

The database DR architecture still determines whether the secondary application can actually function.

---

# 68. Failover Health Strategy

For:

```text
Route53 Alias
     │
     ▼
ALB
```

use:

```text
EvaluateTargetHealth = true
```

where appropriate.

Then ALB's regional target health can inform Route 53 endpoint eligibility.

Remember from Part 2:

```text
DNS failover RTO
=
detection
+
DNS state change
+
resolver cache
+
client retry
+
application recovery
```

Not merely health-check time.

---

# 69. Active-Active DNS Architecture

```text
                        global.example.com
                               │
                               ▼
                            Route 53
                         Latency Routing
                               │
             ┌─────────────────┴──────────────────┐
             ▼                                    ▼
        ap-south-1                          eu-central-1
           ALB                                   ALB
            │                                     │
        application                           application
```

Both Regions:

```text
ACTIVE
```

But remember:

```text
application active-active
```

does not automatically mean:

```text
database active-active.
```

For example:

```text
DynamoDB Global Tables
```

are naturally multi-active.

Aurora Global Database normally centers writes in one primary Region.

---

# 70. Hybrid DNS Layer

Now combine Part 3:

```text
                  On-Premises
                       │
                 Corporate DNS
                       │
                      VPN/DX
                       │
               Inbound Resolver
                       │
                       ▼
                VPC Resolver
                       │
              Private Hosted Zone
```

and reverse:

```text
AWS workload
    │
    ▼
VPC Resolver
    │
    ▼
Resolver rule
    │
    ▼
Outbound Resolver
    │
    ▼
VPN / DX
    │
    ▼
Corporate DNS
```

Our final capstone uses both.

---

# 71. DNS Firewall Layer

Inside AWS:

```text
EC2 / ECS / Lambda
       │
       ▼
 VPC Resolver
       │
       ▼
 DNS Firewall
       │
   ┌───┴────┐
   │        │
ALLOW     BLOCK
```

Use this to:

```text
block known malicious domains
observe suspicious domains
apply domain-based egress controls
```

while remembering:

```text
DNS Firewall
≠
full network firewall.
```

---

# 72. DNS Observability Layer

A mature setup includes:

```text
Public Route 53 metrics

Route 53 health checks

CloudWatch alarms

CloudTrail control-plane auditing

Resolver query logs

DNS Firewall logs/metrics

application SLOs
```

Think:

```text
DNS CONFIGURATION
+
DNS HEALTH
+
DNS QUERY VISIBILITY
+
CHANGE AUDIT
```

not merely:

```text
"we have Route 53."
```

---

# 73. Terraform Production Structure

A Route 53 repository might look:

```text
terraform/
│
├── modules/
│   ├── public-dns/
│   ├── private-dns/
│   ├── dnssec/
│   ├── resolver-endpoints/
│   ├── resolver-rules/
│   ├── dns-firewall/
│   └── health-checks/
│
├── environments/
│   ├── dev/
│   ├── staging/
│   └── prod/
│
└── global/
    ├── route53/
    └── dnssec/
```

This separates global DNS controls from regional application infrastructure.

---

# 74. Terraform Public Zone

```hcl
resource "aws_route53_zone" "public" {
  name = "example.com"

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
```

Remember:

```text
creating hosted zone
```

does not automatically mean the registrar delegates to it unless Route 53 registration/integration performs that step or you explicitly update the registrar.

---

# 75. Terraform Alias to CloudFront

Conceptually:

```hcl
resource "aws_route53_record" "root" {
  zone_id = aws_route53_zone.public.zone_id
  name    = "example.com"
  type    = "A"

  alias {
    name =
      aws_cloudfront_distribution.web.domain_name

    zone_id =
      aws_cloudfront_distribution.web.hosted_zone_id

    evaluate_target_health = false
  }
}
```

Remember:

```text
CloudFront alias target
→ EvaluateTargetHealth false
```

as covered in Part 2.

---

# 76. IPv6 Alias

If the CloudFront distribution supports IPv6 and you want IPv6 DNS:

```hcl
resource "aws_route53_record" "root_ipv6" {
  zone_id = aws_route53_zone.public.zone_id
  name    = "example.com"
  type    = "AAAA"

  alias {
    name =
      aws_cloudfront_distribution.web.domain_name

    zone_id =
      aws_cloudfront_distribution.web.hosted_zone_id

    evaluate_target_health = false
  }
}
```

Production dual-stack DNS often has:

```text
A
+
AAAA
```

when the target/service architecture supports it.

---

# 77. Private Hosted Zone Terraform

```hcl
resource "aws_route53_zone" "internal" {
  name = "internal.example.com"

  vpc {
    vpc_id = aws_vpc.main.id
  }
}
```

Internal services:

```text
api.internal.example.com

jenkins.internal.example.com

monitoring.internal.example.com
```

can live here.

---

# 78. Resolver Terraform

For hybrid DNS:

```text
Inbound Resolver
→ on-prem asks AWS

Outbound Resolver
→ AWS asks on-prem

Rules
→ domain-specific forwarding
```

Part 3 gave the exact resource structure:

```text
aws_route53_resolver_endpoint

aws_route53_resolver_rule

aws_route53_resolver_rule_association
```

Remember the architecture more than the Terraform syntax.

---

# 79. Protect Terraform DNS Changes

Production DNS should normally have:

```text
code review

Terraform plan review

least-privilege execution role

state protection

MFA/approval for high-risk changes

CloudTrail auditing

automated DNS tests
```

A one-line Terraform change can redirect an entire domain.

Treat:

```text
DNS IaC
```

with similar sensitivity to:

```text
IAM
KMS
network perimeter
```

configuration.

---

# 80. Pre-Deployment DNS Validation

Before applying a major DNS change:

```text
1. Validate Terraform plan.

2. Verify hosted zone ID.

3. Confirm public vs private zone.

4. Confirm record type.

5. Verify Alias target.

6. Check TTL.

7. Check health policy.

8. Verify DNSSEC implications.

9. Verify certificates/custom domain.

10. Prepare rollback.
```

Never approve merely because:

```text
terraform plan:
1 to change
```

looks small.

DNS blast radius can be enormous.

---

# 81. Post-Deployment Validation

After DNS deployment:

```bash
dig NS example.com
```

```bash
dig A example.com
```

```bash
dig AAAA example.com
```

```bash
dig www.example.com
```

```bash
dig +trace example.com
```

DNSSEC if enabled:

```bash
dig +dnssec example.com
```

Then test application:

```bash
curl -I https://example.com
```

DNS validation and application validation are separate.

---

# 82. DNS Game Day

A valuable production exercise:

```text
Scenario 1
Primary ALB fails

Scenario 2
One Region disappears

Scenario 3
Wrong record deployed

Scenario 4
Resolver forwarding breaks

Scenario 5
DNS Firewall blocks vendor dependency

Scenario 6
KSK loses KMS access

Scenario 7
Registrar NS accidentally changed
```

For each measure:

```text
Detection time

Alert time

DNS recovery time

Application recovery time

Customer impact

Rollback process
```

This turns DNS from theory into SRE practice.

---

# 83. DNSSEC Incident Game Day

Non-production domain:

```text
1. Verify DNSSEC healthy.

2. Observe DNSKEY.

3. Observe DS.

4. Verify signed response.

5. Review CloudWatch DNSSEC metrics.

6. Simulate controlled KSK issue only
   in safe test environment.

7. Observe ACTION_NEEDED.

8. Restore KMS access.

9. Verify KSK returns healthy.

10. Document runbook.
```

Never experiment with breaking production DNSSEC casually.

---

# 84. Full Production DNS Capstone

Let's build the complete architecture.

Requirements:

```text
Public website:
yourdatascientist.tech

API:
api.yourdatascientist.tech

Primary Region:
ap-south-1

DR Region:
ap-southeast-1

Static content:
CloudFront + S3

API:
ALB + Auto Scaling

Private services:
internal.yourdatascientist.tech

On-prem:
corp.yourdatascientist.tech

Security:
DNSSEC
DNS Firewall

Operations:
query logging
CloudWatch
CloudTrail

Infrastructure:
Terraform
```

---

# 85. Public Frontend

```text
                    Internet User
                         │
                         ▼
             yourdatascientist.tech
                         │
                         ▼
                      Route 53
                         │
                      Alias A
                      Alias AAAA
                         │
                         ▼
                     CloudFront
                         │
                    HTTPS / ACM
                         │
                         ▼
                       OAC
                         │
                         ▼
                    Private S3
```

Properties:

```text
S3 private

CloudFront public

HTTPS enforced

Route 53 Alias

ACM us-east-1

optional DNSSEC
```

---

# 86. Production API

```text
                  api.yourdatascientist.tech
                              │
                              ▼
                           Route 53
                              │
                      Failover / Latency
                              │
                 ┌────────────┴────────────┐
                 ▼                         ▼
              Mumbai                   Singapore
            ap-south-1              ap-southeast-1
                 │                         │
                ALB                       ALB
                 │                         │
           Target Group              Target Group
                 │                         │
                ASG                       ASG
```

Depending on requirement:

```text
Failover
=
active-passive

Latency
=
active-active
```

---

# 87. Data Architecture

For Aurora:

```text
Mumbai
PRIMARY Aurora
      │
      ▼
Aurora Global Database
      │
      ▼
Singapore
SECONDARY
```

Route 53 failover must be coordinated with:

```text
database promotion/failover
```

A DNS failover that sends writes to an application whose database is still read-only:

```text
doesn't solve DR.
```

Always design DNS and data failover together.

---

# 88. Private Application DNS

```text
          AWS application workloads
                    │
                    ▼
             VPC Resolver
                    │
                    ▼
        Private Hosted Zone
 internal.yourdatascientist.tech
                    │
        ┌───────────┼────────────┐
        ▼           ▼            ▼
   payments      monitoring    jenkins
       │             │            │
       ▼             ▼            ▼
 Internal ALB     private IP   internal ALB
```

This prevents internal service discovery from depending on public DNS.

---

# 89. Hybrid DNS

On-premises:

```text
Corporate DNS
```

needs AWS:

```text
*.internal.yourdatascientist.tech
```

Use:

```text
Route 53 inbound Resolver endpoint
```

AWS workloads need:

```text
*.corp.yourdatascientist.tech
```

Use:

```text
Route 53 outbound Resolver endpoint
+
Resolver rule
```

connected through:

```text
VPN / Direct Connect
```

---

# 90. Security Plane

```text
                         DNS SECURITY

                ┌──────────────┼───────────────┐
                ▼              ▼               ▼
             DNSSEC        DNS Firewall       IAM
                │              │               │
             KSK/KMS        domain rules     least privilege
                │
                ▼
            Transfer lock

                │
                ▼
           Query Logging

                │
                ▼
             CloudTrail
```

This is much closer to an enterprise DNS architecture than simply creating one A record.

---

# 91. Observability Plane

```text
Route 53 health checks
          │
          ▼
      CloudWatch
          │
          ▼
        Alarms


VPC Resolver
          │
          ▼
     Query Logs


AWS API changes
          │
          ▼
      CloudTrail


Application
          │
          ▼
   synthetic monitoring
```

The goal:

```text
Can we answer:

Is DNS resolving?

Is it resolving correctly?

Is traffic using the expected Region?

Who changed it?

Is DNSSEC healthy?

Are clients querying malicious names?
```

---

# 92. Complete DNS Production Diagram

```text
                            INTERNET
                               │
                               ▼
                     yourdatascientist.tech
                               │
                               ▼
                            Route 53
                         + DNSSEC Signing
                               │
             ┌─────────────────┴─────────────────┐
             │                                   │
             ▼                                   ▼
         CloudFront                         API Routing
             │                                   │
             ▼                           ┌───────┴────────┐
        Private S3                       ▼                ▼
                                      Mumbai          Singapore
                                        ALB              ALB
                                         │                │
                                         ▼                ▼
                                         ASG              ASG
                                          \                /
                                           \              /
                                            Data / DR layer


────────────────────── PRIVATE AWS DNS ──────────────────────

                        VPC Workloads
                             │
                             ▼
                    Route 53 VPC Resolver
                             │
       ┌─────────────────────┼────────────────────────┐
       ▼                     ▼                        ▼
Private Hosted Zone      DNS Firewall            Resolver Rules
       │                                              │
       ▼                                              ▼
Internal Services                            Outbound Endpoint
                                                      │
                                                  VPN / DX
                                                      │
                                                      ▼
                                                On-Prem DNS
                                                      ▲
                                                      │
                                             Inbound Endpoint
                                                      ▲
                                                      │
                                                 On-Prem Apps
```

If you can understand every arrow in this diagram, Route 53 is no longer just “AWS DNS” to you.

---

# 93. SAA-C03 Scenario

> Need cryptographic validation that public Route 53 DNS responses haven't been tampered with.

Answer:

```text
Route 53 DNSSEC signing
```

plus:

```text
DS chain of trust
```

and the appropriate KMS-backed KSK. ([AWS Documentation][1])

---

# 94. Scenario

> DNSSEC KSK suddenly shows `ACTION_NEEDED`.

Immediate investigation:

```text
KMS key enabled?

KMS key deleted/scheduled deletion?

KMS policy changed?

Route 53 still authorized?
```

Do not ignore the warning because AWS explicitly states prolonged KSK access failure can eventually cause DNS resolution failures for validating resolvers. ([AWS Documentation][6])

---

# 95. Scenario

> Need to migrate a live domain from another DNS provider to Route 53.

Correct approach:

```text
Inventory records
      ↓
lower TTL ahead of time
      ↓
create Route 53 hosted zone
      ↓
copy records
      ↓
test Route 53 authoritative servers
      ↓
change registrar NS
      ↓
keep old DNS running
      ↓
monitor migration
```

AWS's migration procedure explicitly recommends lowering TTL and preparing Route 53 before changing delegation. ([AWS Documentation][14])

---

# 96. Scenario

> New Route 53 records exist but internet clients still use old provider.

Run:

```bash
dig NS example.com
```

If delegation shows old provider:

```text
registrar has not been updated
```

or cached old NS delegation is still in use.

Don't rebuild your ALB.

---

# 97. Scenario

> Route 53 authoritative server gives correct answer but user still sees old IP.

Think:

```text
recursive resolver TTL
```

not:

```text
Route 53 propagation.
```

---

# 98. Scenario

> Domain suddenly returns SERVFAIL only through DNSSEC-validating resolvers.

Investigate:

```text
Parent DS

DNSKEY

RRSIG

KSK status

KMS key/policy
```

before changing application infrastructure. ([AWS Documentation][6])

---

# 99. Scenario

> Need to prevent domain from being transferred away from Route 53 without authorization.

Use:

```text
domain transfer lock
```

where supported for the registered domain. ([AWS Documentation][10])

---

# 100. Scenario

> CI pipeline should modify only `dev.example.com`, not MX or production DNS.

Use Route 53 IAM permissions with fine-grained resource-record-set conditions limiting relevant:

```text
record names
record types
record actions
```

rather than broad `route53:*`. ([AWS Documentation][12])

---

# 101. Scenario

> DNSSEC is currently enabled and we want to disable it.

Correct mental order:

```text
REMOVE DS FROM PARENT

WAIT

VERIFY DS IS GONE

THEN DISABLE SIGNING
```

not the reverse. ([AWS Documentation][8])

---

# 102. Interview Question — Explain Route 53 End to End

A strong answer would be:

> Route 53 is AWS's authoritative DNS and traffic-management service. Public hosted zones provide internet-facing DNS while private hosted zones integrate with Route 53 VPC Resolver for internal resolution. Route 53 Alias records map apex or subdomain names to supported AWS resources such as ALBs and CloudFront. Routing policies include simple, weighted, failover, latency, geolocation, geoproximity, IP-based and multivalue. Health checks or target-health evaluation can make routing failure-aware. Hybrid DNS uses inbound Resolver endpoints for on-premises-to-AWS resolution and outbound endpoints plus forwarding rules for AWS-to-on-premises DNS. Query logging and DNS Firewall add visibility and domain filtering. Public hosted zones can be protected by DNSSEC using a Route 53 KSK backed by an asymmetric customer-managed KMS key in `us-east-1`, with a DS record in the parent zone establishing the DNSSEC chain of trust. ([AWS Documentation][1])

That answer demonstrates architecture instead of simply listing record types.

---

# 103. Route 53 Never-Forget Master Map

```text
ROUTE 53
│
├── DOMAIN REGISTRATION
│      ├── registrar
│      ├── NS delegation
│      └── transfer lock
│
├── PUBLIC DNS
│      ├── Public Hosted Zone
│      ├── A / AAAA
│      ├── Alias
│      ├── CNAME
│      ├── MX / TXT / CAA
│      └── DNSSEC
│
├── TRAFFIC MANAGEMENT
│      ├── Simple
│      ├── Weighted
│      ├── Failover
│      ├── Latency
│      ├── Geolocation
│      ├── Geoproximity
│      ├── IP-based
│      └── Multivalue
│
├── HEALTH
│      ├── Endpoint Health Check
│      ├── Calculated Health
│      ├── CloudWatch Health
│      └── Evaluate Target Health
│
├── PRIVATE DNS
│      ├── Private Hosted Zone
│      ├── VPC Resolver
│      ├── split horizon
│      └── internal service names
│
├── HYBRID DNS
│      ├── Inbound Endpoint
│      ├── Outbound Endpoint
│      ├── Resolver Rules
│      ├── VPN / Direct Connect
│      └── AWS RAM / Profiles
│
├── SECURITY
│      ├── IAM
│      ├── DNSSEC
│      ├── KMS
│      ├── DNS Firewall
│      └── transfer lock
│
└── OBSERVABILITY
       ├── CloudWatch
       ├── Health checks
       ├── Query logs
       └── CloudTrail
```

---

# 104. 25 Route 53 Rules to Burn Into Memory

```text
1. DNS maps names to information needed to reach services.

2. Registrar and DNS hosting are separate roles.

3. NS delegation determines which DNS servers are authoritative.

4. Public Hosted Zone = internet DNS.

5. Private Hosted Zone = private/VPC DNS.

6. A = IPv4.

7. AAAA = IPv6.

8. CNAME maps name → name.

9. Standard CNAME cannot exist at zone apex.

10. Route 53 Alias can target supported AWS resources
    at the apex.

11. TTL controls recursive resolver caching.

12. Weighted routing distributes DNS responses,
    not exact HTTP requests.

13. Failover routing = Primary/Secondary.

14. Latency routing != Geolocation.

15. Evaluate Target Health works with supported Alias targets
    such as ALBs, but not CloudFront.

16. DNS failover RTO includes resolver/client caching.

17. Inbound Resolver = on-prem asks AWS.

18. Outbound Resolver = AWS asks on-prem.

19. Private DNS resolution does not create network connectivity.

20. DNS Firewall filters VPC Resolver domain queries.

21. DNSSEC provides authenticity/integrity,
    not confidentiality.

22. Route 53 DNSSEC KSK uses a KMS asymmetric
    ECC_NIST_P256 signing key in us-east-1.

23. DNSSEC enablement:
    sign first → then add DS.

24. DNSSEC disablement:
    remove DS → wait → disable signing.

25. DNS is a critical security and availability control plane.
```

The most important Route 53 troubleshooting rule remains:

```text
NAME DOESN'T RESOLVE
        │
        ▼
FIX DNS FIRST

NAME RESOLVES
        │
        ▼
THEN debug:
network
ALB
SG
EC2
application
database
```

---

# ✅ Lesson 29 — Amazon Route 53 & DNS Architecture COMPLETE

You now understand the complete Route 53 stack:

```text
✓ DNS hierarchy
✓ root / TLD / authoritative DNS
✓ recursive resolvers
✓ registrar vs DNS provider
✓ public hosted zones
✓ private hosted zones
✓ A / AAAA
✓ CNAME
✓ Alias
✓ MX / TXT / CAA / NS / SOA
✓ TTL
✓ negative caching
✓ dig / dig +trace
✓ Simple routing
✓ Weighted routing
✓ Failover routing
✓ Latency routing
✓ Geolocation
✓ Geoproximity
✓ IP-based routing
✓ Multivalue
✓ active-active
✓ active-passive
✓ health checks
✓ Evaluate Target Health
✓ fail-open behavior
✓ VPC Resolver
✓ AmazonProvidedDNS
✓ split-horizon DNS
✓ inbound Resolver endpoints
✓ outbound Resolver endpoints
✓ forwarding rules
✓ hybrid DNS
✓ VPN/DX DNS integration
✓ multi-account DNS
✓ AWS RAM
✓ Route 53 Profiles
✓ Resolver Query Logging
✓ DNS Firewall
✓ PrivateLink private DNS
✓ DNSSEC
✓ KSK
✓ ZSK
✓ DNSKEY
✓ RRSIG
✓ DS
✓ DNSSEC chain of trust
✓ KMS DNSSEC architecture
✓ us-east-1 KMS requirement
✓ DNSSEC monitoring
✓ safe DNSSEC enable/disable
✓ transfer locks
✓ Route 53 IAM
✓ DNS migration
✓ TTL migration planning
✓ Terraform
✓ production troubleshooting
✓ multi-Region DNS
✓ enterprise hybrid DNS
✓ full production capstone
```

---

# Next — Lesson 30

# **AWS IAM & Enterprise Security Architecture**

Now we move into one of the most important sections of the entire AWS journey.

You've already used IAM repeatedly and encountered errors such as:

```text
AccessDenied

UnauthorizedOperation

not authorized to perform

explicit deny

KMS denied

ECR CreateRepository denied

EC2 DescribeSecurityGroups denied
```

Lesson 30 will rebuild IAM from first principles rather than treating policies as random JSON:

```text
                         AWS REQUEST
                              │
                              ▼
                       WHO ARE YOU?
                              │
                    ┌─────────┴─────────┐
                    ▼                   ▼
                 HUMAN              WORKLOAD
                    │                   │
              IAM Identity           IAM Role
              Identity Center       EC2/ECS/Lambda
                    │                   │
                    └────────┬──────────┘
                             ▼
                       AUTHENTICATION
                             │
                             ▼
                      AUTHORIZATION
                             │
            ┌────────────────┼──────────────────┐
            ▼                ▼                  ▼
      Identity Policy   Resource Policy      SCP
            │                │                  │
            ├──────── Permissions Boundary ─────┤
            │
            ├──────── Session Policy ───────────┤
            │
            ▼
      VPC endpoint policy
            │
            ▼
      KMS key policy
            │
            ▼
       EXPLICIT DENY?
            │
       ┌────┴────┐
      YES       NO
       │         │
       ▼         ▼
     DENY      ALLOW?
                  │
             ┌────┴────┐
            YES       NO
             │         │
             ▼         ▼
           ALLOW    IMPLICIT DENY
```

We'll cover **IAM users, groups, roles, policies, principals, actions, resources, conditions, evaluation logic, explicit deny, resource policies, cross-account access, trust policies, STS, AssumeRole, temporary credentials, instance profiles, IAM Identity Center, federation, SAML/OIDC, GitHub Actions OIDC, permissions boundaries, Organizations SCPs, session policies, ABAC, tags, PassRole, confused deputy, ExternalId, MFA, Access Analyzer, credential reports, IAM Access Advisor, least privilege, KMS interaction, VPC endpoint policies, S3 policy troubleshooting, ECR permissions, EC2 permissions, Terraform IAM modules, privilege-escalation prevention, and a full production multi-account security capstone**.

That lesson will give you a reusable method for answering almost any AWS question beginning with:

> **“Why am I getting AccessDenied?”**

[1]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/dns-configuring-dnssec.html?utm_source=chatgpt.com "Configuring DNSSEC signing in Amazon Route 53 - Amazon Route 53"
[2]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/dns-configuring-dnssec-enable-signing.html?utm_source=chatgpt.com "Enabling DNSSEC signing and establishing a chain of trust - Amazon Route 53"
[3]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/dns-configuring-dnssec-ksk.html?utm_source=chatgpt.com "Working with key-signing keys (KSKs) - Amazon Route 53"
[4]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/dns-configuring-dnssec-zsk-management.html?utm_source=chatgpt.com "KMS key and ZSK management in Route 53 - Amazon Route 53"
[5]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/dns-configuring-dnssec-cmk-requirements.html?utm_source=chatgpt.com "Working with customer managed keys for DNSSEC - Amazon Route 53"
[6]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/dns-configuring-dnssec-troubleshoot.html?utm_source=chatgpt.com "Troubleshooting DNSSEC signing - Amazon Route 53"
[7]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/monitoring-hosted-zones-with-cloudwatch.html?utm_source=chatgpt.com "Monitoring hosted zones using Amazon CloudWatch - Amazon Route 53"
[8]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/dns-configuring-dnssec-disable.html?utm_source=chatgpt.com "Disabling DNSSEC signing - Amazon Route 53"
[9]: https://registry.terraform.io/providers/-/aws/latest/docs/resources/route53_key_signing_key?utm_source=chatgpt.com "aws_route53_key_signing_key | Resources | hashicorp/aws"
[10]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/domain-lock.html?utm_source=chatgpt.com "Locking a domain to prevent unauthorized transfer to another ..."
[11]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resource-record-sets-permissions.html?utm_source=chatgpt.com "Resource record set permissions - Amazon Route 53"
[12]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/specifying-conditions-route53.html?utm_source=chatgpt.com "Using IAM policy conditions for fine-grained access control"
[13]: https://docs.aws.amazon.com/Route53/latest/APIReference/API_ChangeResourceRecordSets.html?utm_source=chatgpt.com "ChangeResourceRecordSets - Amazon Route 53"
[14]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/migrate-dns-domain-in-use.html?utm_source=chatgpt.com "Making Route 53 the DNS service for a domain that's in use"
[15]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/SOA-NSrecords.html?utm_source=chatgpt.com "NS and SOA records that Amazon Route 53 creates for a ..."
[16]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/troubleshooting-new-dns-settings-not-in-effect.html?utm_source=chatgpt.com "I changed DNS settings, but they haven't taken effect"
