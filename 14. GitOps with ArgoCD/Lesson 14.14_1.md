# Module 14 — GitOps with Argo CD

## Lesson 14.14 — Sync Windows, Change Control & Production Deployment Governance

We have now built several layers:

```text
Git
 │
 ▼
Application
 │
 ▼
AppProject
 │
 ├── Which repos?
 ├── Which clusters?
 ├── Which namespaces?
 └── Which resource types?
 │
 ▼
Argo CD RBAC
 │
 └── Who may sync?
 │
 ▼
Kubernetes
```

But production needs one more question:

> **Even if everything is authorized, are we allowed to deploy right now?**

That is the problem solved by **Argo CD Sync Windows**.

---

# 1. The enterprise problem

Imagine this change is fully legitimate:

```text
Developer
    │
    ▼
Pull Request
    │
    ▼
Code Review ✅
    │
    ▼
CI Tests ✅
    │
    ▼
Image Scan ✅
    │
    ▼
GitOps manifest updated ✅
    │
    ▼
Argo CD detects commit
```

Everything looks good.

But it's:

```text
Friday
5:45 PM
```

and your company says:

```text
NO NORMAL PRODUCTION DEPLOYMENTS
AFTER 5 PM FRIDAY
```

Without deployment governance:

```text
Git commit
    ↓
Auto Sync
    ↓
Production

😬
```

Instead we want:

```text
Git commit
    ↓
Argo CD sees OutOfSync
    ↓
Check Sync Window
    ↓

Is deployment allowed now?

      NO
      │
      ▼

Wait
```

Argo CD Sync Windows are time-based controls defined on an `AppProject`; they can either **allow** or **deny** synchronization during scheduled periods. ([Argo CD][1])

---

# 2. Sync Window mental model

Think of:

```text
RBAC
=
WHO may deploy?


AppProject
=
WHAT / WHERE may be deployed?


Sync Window
=
WHEN may it deploy?
```

The complete model becomes:

```text
                    Deployment Request

                           │
                           ▼

                      WHO?
                           │
                      Argo RBAC
                           │
                           ▼

                    WHAT / WHERE?
                           │
                      AppProject
                           │
                           ▼

                       WHEN?
                           │
                     Sync Window
                           │
                           ▼

                       DEPLOY
```

This is an excellent enterprise GitOps model.

---

# 3. Where Sync Windows live

Sync Windows belong to:

```yaml
kind: AppProject
```

not normally to individual `Application` manifests.

Example:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject

metadata:
  name: todo-team
  namespace: argocd

spec:

  syncWindows:

    - kind: allow
      schedule: '0 10 * * 1-4'
      duration: 8h
      applications:
        - '*-production'
```

Argo CD supports scheduling a window with a cron expression plus a duration, and targeting Applications by application name, destination namespace, or destination cluster. ([Argo CD][1])

---

# 4. Two types of Sync Windows

There are two fundamental kinds:

```text
ALLOW
DENY
```

## Allow window

Means:

> Synchronization is permitted during this window.

Example:

```text
10 AM ─────────────────── 6 PM

         ALLOW
```

Outside:

```text
blocked
```

assuming this matching allow policy controls the application.

---

## Deny window

Means:

> Synchronization is prohibited during this window.

Example:

```text
                    Friday Freeze

5 PM ───────────────────────── Midnight
                  DENY
```

When an active allow and active deny window both match an Application, the **deny window wins**. ([Argo CD][1])

### Never forget

```text
ALLOW + DENY active
       │
       ▼
     DENY WINS
```

---

# 5. No matching window

Suppose an application has:

```text
NO matching Sync Window
```

Then Argo CD does not restrict synchronization based on Sync Windows.

```text
No matching window
       ↓
Sync allowed
```

Argo CD's current rules are:

```text
No matching windows
        ↓
sync allowed

Matching allow windows exist
        ↓
at least an applicable allow window
must be active

Active deny window
        ↓
sync blocked
```

([Argo CD][1])

This distinction is very important.

---

# 6. Production policy example

Let's design a company rule:

```text
Production deployment:

Monday    10 AM – 6 PM ✅
Tuesday   10 AM – 6 PM ✅
Wednesday 10 AM – 6 PM ✅
Thursday  10 AM – 6 PM ✅

Friday     ❌
Saturday   ❌
Sunday     ❌
```

We could define:

```yaml
syncWindows:

  - kind: allow

    schedule: '0 10 * * 1-4'

    duration: 8h

    timeZone: Asia/Kolkata

    applications:

      - '*-production'
```

The current CLI supports an explicit time zone for sync windows; if you don't specify one through the CLI, its documented default is UTC, so being explicit is safer for globally distributed teams. ([Argo CD][2])

---

# 7. Understanding the cron expression

This:

```text
0 10 * * 1-4
```

means:

```text
┌──────── minute
│ ┌────── hour
│ │ ┌──── day of month
│ │ │ ┌── month
│ │ │ │ ┌ day of week
│ │ │ │ │
0 10 * * 1-4
```

So:

```text
minute = 0
hour   = 10

day of week:
1 = Monday
2 = Tuesday
3 = Wednesday
4 = Thursday
```

Then:

```yaml
duration: 8h
```

gives us:

```text
10:00
  │
  ▼
ALLOW
  │
  │ 8 hours
  ▼
18:00
```

---

# 8. Why I strongly recommend setting the timezone

Imagine an Indian operations team expects:

```text
10 AM IST
```

but the window is interpreted as:

```text
10 AM UTC
```

That becomes:

```text
3:30 PM IST
```

Suddenly the deployment schedule is wrong by **5½ hours**.

So prefer:

```yaml
timeZone: Asia/Kolkata
```

rather than mentally converting cron schedules from UTC.

Current Argo CD supports named time zones on Sync Windows. ([Argo CD][1])

---

# 9. Target only production Applications

Our project might contain:

```text
todo-dev
todo-staging
todo-production
payment-dev
payment-production
```

We don't necessarily want a restrictive deployment window for development.

Use:

```yaml
applications:

  - '*-production'
```

Then:

```text
todo-production       ✅ window applies
payment-production    ✅ window applies

todo-dev              ❌ window doesn't match
todo-staging          ❌ window doesn't match
```

Wildcards are supported for Sync Window matching. ([Argo CD][1])

---

# 10. Match by namespace

You don't have to target Applications by name.

Suppose all production workloads use:

```text
*-prod
```

namespaces.

You could use:

```yaml
namespaces:

  - '*-prod'
```

Then applications deploying into:

```text
todo-prod
payment-prod
analytics-prod
```

can all fall under the window.

Sync Windows may select Applications by the Application's destination namespace. ([Argo CD][1])

---

# 11. Match by cluster

Suppose you have:

```text
dev-eks
staging-eks
prod-eks
```

You can target:

```yaml
clusters:

  - prod-eks
```

Architecture:

```text
Argo CD

   │
   ├── dev-eks
   │      no window
   │
   ├── staging-eks
   │      no window
   │
   └── prod-eks
          │
          ▼
      Sync Window
```

Cluster destination is another supported selector. ([Argo CD][1])

---

# 12. Application + namespace + cluster selectors

You can specify multiple selector types:

```yaml
applications:
  - todo-*

namespaces:
  - '*-production'

clusters:
  - prod-eks
```

Here's the subtle part.

By default, Argo CD treats these selector categories approximately as:

```text
Application matches
       OR
Namespace matches
       OR
Cluster matches
```

So **any matching selector can cause the Sync Window to apply**. ([Argo CD][1])

---

# 13. OR matching can surprise you

Suppose:

```yaml
applications:
  - todo-*

namespaces:
  - '*-production'
```

You may think this means:

```text
Todo applications
AND
production namespace
```

But the default behavior is effectively:

```text
Todo application
OR
production namespace
```

Therefore:

```text
todo-dev
```

could match because:

```text
application = todo-*
```

even though it isn't production.

This is an easy configuration mistake.

---

# 14. AND matching

Current Argo CD provides an option to use an AND operator instead of the default OR behavior. ([Argo CD][2])

CLI:

```bash
argocd proj windows add todo-team \
  --kind allow \
  --schedule "0 10 * * 1-4" \
  --duration 8h \
  --applications "todo-*" \
  --namespaces "*-production" \
  --use-and-operator
```

Conceptually:

```text
Application starts todo-
          AND
Namespace ends -production
          │
          ▼
window applies
```

This can make multi-dimensional policies much safer.

---

# 15. Deny window example

Now let's add a change freeze.

Suppose:

```text
Every day:
22:00 → 06:00

No production deployments.
```

We can define:

```yaml
- kind: deny

  schedule: '0 22 * * *'

  duration: 8h

  timeZone: Asia/Kolkata

  applications:

    - '*-production'
```

Then:

```text
21:59  ✅

22:00
  │
  ▼
DENY ACTIVE

...
05:59 ❌

06:00
  │
  ▼
window ends
```

---

# 16. Why have both allow and deny?

At first you might ask:

> Why not use only one?

Because they solve slightly different governance models.

### Allow-style governance

```text
Deployment is forbidden
unless it is inside
approved deployment hours.
```

This is restrictive by default.

---

### Deny-style governance

```text
Deployment is generally allowed
except during specific freeze periods.
```

This is permissive by default.

For sensitive production systems, allow-style windows often make policy easier to reason about.

---

# 17. Example: month-end finance freeze

Imagine a financial application where the company says:

```text
Month-end processing:

No deployment
from 8 PM to midnight.
```

A deny window could target only:

```text
finance-production
```

rather than freezing the whole company.

```yaml
- kind: deny

  schedule: '0 20 28-31 * *'

  duration: 4h

  applications:

    - finance-production
```

For complicated business calendars, though, remember that cron is not a full business-calendar engine.

Things such as:

```text
last working day
public holidays
quarter close
regulatory blackout
```

may require external governance/workflow logic rather than trying to encode everything into a single cron expression.

---

# 18. Sync Windows + automated sync

Remember Lesson 14.12:

```yaml
syncPolicy:

  automated:

    enabled: true
    prune: true
    selfHeal: true
```

Normally:

```text
Git change
   ↓
OutOfSync
   ↓
Auto Sync
   ↓
Production
```

But with an inactive allow window:

```text
Git change
   ↓
OutOfSync
   ↓
Auto Sync wants to execute
   ↓
Sync Window check
   ↓
BLOCKED
```

Sync Windows apply to automated synchronization as well as manual synchronization. ([Argo CD][1])

---

# 19. Important: blocked does NOT mean Git change disappears

Suppose Git receives:

```text
image: todo:v5
```

while the deployment window is closed.

Cluster still has:

```text
todo:v4
```

Argo CD can see:

```text
Desired:
v5

Live:
v4
```

Therefore:

```text
Application:
OutOfSync
```

But:

```text
Sync Window:
Denied
```

So the mental model is:

```text
Git change accepted
       │
       ▼
Argo sees new desired state
       │
       ▼
Application OutOfSync
       │
       X
cannot reconcile yet
       │
       ▼
Wait until permitted
```

The window controls **synchronization**, not whether Git can receive a commit.

---

# 20. Sync Window is not a Git approval mechanism

This distinction matters.

Argo CD Sync Windows do **not** replace:

```text
Pull Request reviews
branch protection
CODEOWNERS
CI tests
security checks
change approval
```

They answer only:

```text
Can synchronization happen now?
```

A mature production flow looks more like:

```text
Developer
   │
   ▼
Pull Request
   │
   ├── Code Review
   ├── CI
   ├── Security Scan
   └── Approval
          │
          ▼
Merge
          │
          ▼
GitOps desired state
          │
          ▼
Argo CD
          │
          ▼
RBAC
          │
          ▼
AppProject
          │
          ▼
Sync Window
          │
          ▼
Kubernetes
```

---

# 21. Manual Sync override

Now imagine a P1 incident.

Production is broken.

Git already contains the fix.

Unfortunately:

```text
Current time:
2:00 AM

Sync Window:
DENY
```

Waiting until 10 AM is unacceptable.

Argo CD supports configuring a Sync Window to allow **manual synchronization** even when the window would otherwise prevent normal synchronization. ([Argo CD][1])

For example:

```yaml
- kind: deny

  schedule: '0 22 * * *'

  duration: 8h

  applications:

    - '*-production'

  manualSync: true
```

Think:

```text
Automated deployment
        ❌

Authorized emergency manual sync
        ✅
```

---

# 22. Important: manualSync does NOT mean everyone can bypass policy

Remember Lesson 14.13.

A user still needs:

```text
applications, sync
```

permission through Argo CD RBAC.

So:

```text
Sync Window
manualSync = true
       │
       ▼
"Manual bypass is technically permitted."
```

but RBAC still asks:

```text
"Is THIS USER allowed to sync?"
```

This gives us multiple controls:

```text
Emergency Manual Deployment

        │
        ▼

Window permits manual override?
        │
       YES
        │
        ▼

Does operator have sync RBAC?
        │
       YES
        │
        ▼

AppProject valid?
        │
       YES
        │
        ▼

DEPLOY
```

---

# 23. Production emergency model

A good structure could be:

```text
Developers
     │
     └── cannot manually sync production


SRE On-call
     │
     └── may manually sync production


Platform Admin
     │
     └── may modify Sync Window policy
```

That's much better than:

```text
Everyone:
admin
```

---

# 24. Break-glass deployment

You will hear:

```text
break-glass access
```

This means:

> Exceptional emergency access used when normal controls must be bypassed to restore service.

In GitOps:

```text
Normal deployment

PR
 ↓
approval
 ↓
window
 ↓
auto-sync


Emergency deployment

incident declared
 ↓
approved fix in Git
 ↓
authorized operator
 ↓
manual sync exception
 ↓
production
 ↓
incident/audit record
```

The goal is not to eliminate emergencies.

The goal is to make emergency access:

```text
limited
auditable
intentional
reversible
```

---

# 25. CLI: add an allow window

Example:

```bash
argocd proj windows add todo-team \
  --kind allow \
  --schedule "0 10 * * 1-4" \
  --duration 8h \
  --applications "*-production" \
  --time-zone "Asia/Kolkata"
```

Current Argo CD exposes `argocd proj windows add` with options for kind, cron schedule, duration, applications, namespaces, clusters, manual sync, sync overrun, timezone, and AND matching. ([Argo CD][2])

---

# 26. List the windows

```bash
argocd proj windows list todo-team
```

This shows information including:

```text
ID
STATUS
KIND
SCHEDULE
DURATION
APPLICATIONS
NAMESPACES
CLUSTERS
MANUALSYNC
SYNCOVERRUN
TIMEZONE
```

Current Argo CD exposes this state through its CLI. ([Argo CD][1])

---

# 27. Check the Application itself

Run:

```bash
argocd app get todo-production
```

Current Argo CD includes matching Sync Window state when inspecting an Application, so you can see information such as whether synchronization is allowed or denied and which windows apply. ([Argo CD][1])

This should become one of your first troubleshooting commands:

```bash
argocd app get todo-production
```

---

# 28. Change manual override from CLI

Suppose window ID is:

```text
2
```

Enable manual sync exception:

```bash
argocd proj windows enable-manual-sync \
  todo-team \
  2
```

Disable again:

```bash
argocd proj windows disable-manual-sync \
  todo-team \
  2
```

Both operations are supported by the current Argo CD CLI. ([Argo CD][1])

---

# 29. Newer production concept: Sync Overrun

Here's a subtle operational problem.

Your allowed deployment window is:

```text
10:00 → 18:00
```

A deployment starts:

```text
17:58
```

but the deployment takes:

```text
10 minutes
```

What should happen at:

```text
18:00?
```

Argo CD now has a control called:

```yaml
syncOverrun: true
```

that can allow already-running automatic syncs to continue across the boundary of a Sync Window. ([Argo CD][1])

---

# 30. Without syncOverrun

Imagine:

```text
17:58
   │
   ▼
Sync begins

17:59
   │
   ▼
PreSync migration running

18:00
   │
   ▼
Allow window ends
```

Depending on the applicable window transition rules, a sync without overrun permission may become blocked.

That's dangerous because a deployment can be partially through its workflow.

---

# 31. With syncOverrun

```yaml
- kind: allow

  schedule: '0 10 * * 1-4'

  duration: 8h

  syncOverrun: true

  applications:

    - '*-production'
```

Now conceptually:

```text
17:58
Sync legitimately starts
      │
      ▼
18:00
Window closes
      │
      ▼
Existing sync
may finish
      │
      ▼

New sync?
      ❌
```

For an allow window, `syncOverrun` permits a synchronization that started while the window was active to continue after that window ends, subject to interactions with other matching windows. ([Argo CD][1])

---

# 32. Deny window + syncOverrun

It also works with deny windows.

Imagine:

```text
Deployment starts: 21:58

Freeze starts:     22:00
```

A deny window with:

```yaml
syncOverrun: true
```

can allow a synchronization that was already legitimately running before the deny period to finish, while still blocking **new** syncs during the deny window. ([Argo CD][1])

Mental model:

```text
                  DENY WINDOW
                     starts
                       │
                       ▼

existing sync ────────────────► allowed to finish

new sync
     │
     X
   denied
```

---

# 33. Why syncOverrun is important

Suppose your deployment contains:

```text
PreSync DB migration
      ↓
Backend deployment
      ↓
Frontend
      ↓
PostSync smoke test
```

Stopping arbitrary progress at the exact minute a window closes can produce an undesirable half-finished operational state.

`syncOverrun` lets you create this governance rule:

> **Don't begin another deployment, but let the already-approved deployment finish.**

That's much more operationally sensible for many production environments.

---

# 34. But don't confuse overrun with unlimited access

`syncOverrun=true` does **not** mean:

```text
the window no longer matters
```

It means approximately:

```text
Already legitimately started
      │
      ▼
may continue

New operation
      │
      X
must obey current window
```

Argo CD also evaluates interactions between multiple allow and deny windows; for example, a new deny window without overrun permission can block continued execution. ([Argo CD][1])

---

# 35. Full production AppProject example

Let's upgrade our `todo-team` project:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject

metadata:

  name: todo-team
  namespace: argocd

spec:

  description: Todo application production security boundary

  sourceRepos:

    - https://github.com/company/todo-gitops.git

  destinations:

    - server: https://kubernetes.default.svc
      namespace: todo-dev

    - server: https://kubernetes.default.svc
      namespace: todo-staging

    - server: https://kubernetes.default.svc
      namespace: todo-production


  syncWindows:

    # Production deployment window

    - kind: allow

      schedule: '0 10 * * 1-4'

      duration: 8h

      timeZone: Asia/Kolkata

      applications:

        - todo-production

      syncOverrun: true


    # Night freeze

    - kind: deny

      schedule: '0 22 * * *'

      duration: 8h

      timeZone: Asia/Kolkata

      applications:

        - todo-production

      manualSync: true

      syncOverrun: true
```

These fields are supported in current AppProject Sync Window configuration. ([Argo CD][3])

---

# 36. Translate this manifest into English

### Rule 1

```text
Monday–Thursday
10 AM–6 PM IST

todo-production
may sync.
```

### Rule 2

```text
Night freeze:
10 PM–6 AM

normal sync blocked.
```

### Rule 3

```text
Emergency authorized
manual sync:

possible.
```

### Rule 4

```text
Deployment already in progress
when window changes:

may continue,
subject to matching window rules.
```

Now we're doing actual deployment governance.

---

# 37. Friday behaviour

Our allow rule is:

```text
1-4
```

meaning:

```text
Monday
Tuesday
Wednesday
Thursday
```

On Friday there is **no active matching allow window**.

Because this Application has matching allow-window policy, normal synchronization is not permitted merely because the deny window is inactive. Argo CD requires an applicable allow window to be active when matching allow windows exist. ([Argo CD][1])

So:

```text
Friday 2 PM

Night deny active?
      NO

Allow active?
      NO

Result:
      BLOCKED
```

Very important.

---

# 38. Deny does not mean "allow whenever deny is inactive" if allow windows also exist

This is another common misunderstanding.

Suppose:

```text
Allow:
Mon-Thu 10-18

Deny:
22-06
```

Friday at noon:

```text
Deny inactive
```

but:

```text
Allow also inactive
```

Therefore:

```text
❌ blocked
```

because matching allow windows exist but none are active. ([Argo CD][1])

---

# 39. Hands-on laboratory

Let's test this in your Kubernetes/Argo CD environment when you reach the lab.

First inspect the project:

```bash
argocd proj get todo-team
```

Then:

```bash
argocd proj windows list todo-team
```

Now add a short test window.

For learning purposes, instead of waiting until a particular weekday, create a window that becomes active around your test time.

Example pattern:

```bash
argocd proj windows add todo-team \
  --kind deny \
  --schedule "<test cron>" \
  --duration 10m \
  --applications "todo-production" \
  --time-zone "Asia/Kolkata"
```

Then inspect:

```bash
argocd app get todo-production
```

---

# 40. Test deployment while blocked

Change Git:

```yaml
image:

  repository: nginx

  tag: "1.29"
```

Then:

```bash
git add .
git commit -m "test production sync window"
git push
```

Argo CD should detect:

```text
Git revision changed
      │
      ▼
OutOfSync
```

but if the deny window is active:

```text
Synchronization
      │
      X
blocked
```

---

# 41. What you should observe

Conceptually:

```text
Application:

Sync Status:
OutOfSync

Health:
Healthy

Sync Window:
Sync Denied
```

This situation is completely valid:

```text
HEALTHY
+
OUT OF SYNC
+
SYNC BLOCKED
```

They're three separate concepts.

---

# 42. Never confuse these three statuses

### Health

```text
Is the current running workload healthy?
```

### Sync

```text
Does live Kubernetes state match desired Git state?
```

### Sync Window

```text
Is Argo CD permitted to synchronize right now?
```

Therefore:

```text
Current production v4:
Healthy ✅

Git wants v5:
OutOfSync ⚠

Window closed:
Sync Denied 🔒
```

There's nothing contradictory about this.

---

# 43. At the next allowed window

When the allow window becomes active:

```text
10:00 AM
   │
   ▼
Allow window active
   │
   ▼
Application still OutOfSync
   │
   ▼
auto-sync
   │
   ▼
v5 deployed
```

This lets Git remain the source of truth without forcing the deployment to happen immediately.

---

# 44. Production change-management architecture

Now combine this with a realistic company process:

```text
                    Developer

                       │
                       ▼
                  Code Commit

                       │
                       ▼
                  Pull Request

          ┌────────────┼────────────┐
          ▼            ▼            ▼

      Unit Tests      SAST       Code Review

          │            │            │
          └────────────┼────────────┘
                       ▼

                    MERGED

                       │
                       ▼

                  Build Image
                       │
                       ▼
                  Scan Image
                       │
                       ▼
                     ECR

                       │
                       ▼

              GitOps Repository

                       │
                       ▼

                    Argo CD

                       │
                       ▼

                     RBAC
                "Who can deploy?"

                       │
                       ▼

                   AppProject
             "Where/what may deploy?"

                       │
                       ▼

                  Sync Window
                "Can deploy now?"

                       │
                       ▼

                 Sync Phases

              PreSync → Sync
                        ↓
                     PostSync

                       │
                       ▼

                   Kubernetes
```

That's a serious production GitOps architecture.

---

# 45. Where does a change ticket fit?

Some companies use:

```text
ServiceNow
Jira
Change Request systems
```

Argo CD Sync Windows themselves do not magically validate:

```text
ServiceNow CRQ-123 approved?
```

Instead you normally combine controls.

For example:

```text
Change ticket
      │
      ▼
approval workflow
      │
      ▼
Pull Request approved
      │
      ▼
Git merge
      │
      ▼
deployment window
      │
      ▼
Argo CD
```

or:

```text
Approved change
      │
      ▼
authorized operator
      │
      ▼
manual production sync
```

So treat Sync Windows as **one layer** of change governance, not the entire change-management system.

---

# 46. Production freeze example

Suppose there's a major sale:

```text
Black Friday
```

Business says:

```text
NO DEPLOYMENTS

Thursday 18:00
through
Saturday 06:00
```

You could add a temporary deny window at the AppProject level.

Architecture:

```text
Regular Window
      │
      ▼
deployments normally allowed


Temporary Freeze
      │
      ▼
DENY
      │
      ▼
overrides allow
```

Remember:

```text
ALLOW active
+
DENY active
=
DENY
```

([Argo CD][1])

---

# 47. This makes temporary freezes easier

Without Sync Windows, companies sometimes do dangerous things like:

```text
disable Argo CD
```

or:

```text
scale application-controller to 0
```

or:

```text
remove repository credentials
```

or:

```text
disable automation everywhere
```

Those are crude platform-wide changes.

A Sync Window is much cleaner:

```text
Change freeze policy
      │
      ▼
AppProject
      │
      ▼
Target only relevant production apps
```

---

# 48. Don't disable reconciliation casually

Remember:

```text
Reconciliation
```

does more than blindly deploy things.

Argo CD still needs to:

```text
observe
compare
report status
detect drift
```

A deployment freeze generally means:

```text
don't synchronize
```

not:

```text
make Argo CD blind
```

This distinction improves visibility during a freeze.

---

# 49. Common troubleshooting scenario

Engineer says:

> My Git commit is merged, but Argo CD isn't deploying.

Do **not** immediately restart Argo CD.

Use:

```bash
argocd app get todo-production
```

Then reason:

```text
1. Did Argo detect Git revision?
        │
        ▼

2. Is Application OutOfSync?
        │
        ▼

3. Is automated sync enabled?
        │
        ▼

4. Is a Sync Window blocking?
        │
        ▼

5. Does RBAC permit manual sync?
        │
        ▼

6. Does AppProject allow destination?
        │
        ▼

7. Are PreSync hooks/waves failing?
```

This is a much better troubleshooting workflow.

---

# 50. Another troubleshooting scenario

You see:

```text
SyncWindow:
Sync Denied
```

Check:

```bash
argocd proj windows list todo-team
```

Look at:

```text
STATUS
KIND
SCHEDULE
DURATION
TIMEZONE
APPLICATIONS
NAMESPACES
CLUSTERS
MANUALSYNC
SYNCOVERRUN
```

Then ask:

```text
Which matching window is active?
```

Don't guess.

---

# 51. Time-zone error

Very common scenario:

```text
Window should begin:
10:00 AM IST

But Argo says:
Inactive
```

Check:

```text
timeZone
```

If omitted:

```text
cron may not mean what the team thinks it means
```

Use explicit:

```yaml
timeZone: Asia/Kolkata
```

Current Argo CD's window CLI defaults the time zone to UTC when one is not supplied. ([Argo CD][2])

---

# 52. Selector error

Window:

```yaml
applications:

  - todo-production
```

Actual Application:

```text
todo-prod
```

Then:

```text
No match
```

The window will not govern the application through that selector.

Check exact Application names:

```bash
argocd app list
```

---

# 53. OR-vs-AND error

Configuration:

```yaml
applications:
  - todo-*

namespaces:
  - '*-production'
```

Engineer expects:

```text
todo + production only
```

But default selector combination:

```text
OR
```

may match far more Applications.

Current Argo CD provides `--use-and-operator` specifically when AND semantics are desired. ([Argo CD][2])

This is one of the most important configuration traps in this lesson.

---

# 54. Manual override doesn't work

Engineer has:

```yaml
manualSync: true
```

but still can't sync.

Check:

```text
1. Argo RBAC

applications,sync
       ?

2. Is correct Sync Window matching?

3. Is another deny window active?

4. Does AppProject permit app destination?

5. Is user operating on correct Application?
```

Remember:

```text
manualSync
     ≠
admin permission
```

---

# 55. Multiple windows

A single Application may be affected by multiple Sync Windows, and a single Sync Window can affect multiple Applications. ([Argo CD][1])

Example:

```text
todo-production
     │
     ├── company business-hours allow
     │
     ├── production night deny
     │
     └── Black Friday deny
```

Argo CD evaluates them together.

This is very powerful.

It is also why poorly designed windows can become confusing.

---

# 56. Keep policy understandable

Bad:

```text
27 overlapping windows
with random cron schedules
and wildcard patterns
```

Nobody can answer:

```text
"Can we deploy at 4 PM?"
```

Good:

```text
Company production allow window
       +
clearly named freeze exceptions
       +
explicit emergency override policy
```

Governance should be easy to explain.

---

# 57. Recommended GitOps ownership

Treat the `AppProject` containing production Sync Windows as **platform/security configuration**.

Meaning ordinary application developers usually should not casually change:

```yaml
syncWindows:
```

Otherwise:

```text
Developer wants Friday deployment
        │
        ▼
changes:
deny → allow
        │
        ▼
security control defeated
```

The repository containing AppProjects should therefore have stronger ownership and review controls than ordinary application manifests.

---

# 58. Repository separation pattern

A strong architecture might be:

```text
application-source/
│
├── backend code
└── frontend code


application-gitops/
│
├── dev/
├── staging/
└── production/


platform-gitops/
│
├── argocd/
│   ├── projects/
│   ├── rbac/
│   └── applicationsets/
│
├── ingress/
├── observability/
└── policies/
```

Then:

```text
Application developers

write:
application code
application manifests


Platform/SRE

controls:
AppProjects
RBAC
Sync Windows
cluster registration
platform policies
```

Clear ownership again.

---

# 59. Production governance layers

You should now think in **layers**, not one magic security feature.

```text
Layer 1
Git permissions

        ↓

Layer 2
Pull Request approvals

        ↓

Layer 3
CI quality/security gates

        ↓

Layer 4
Argo CD authentication

        ↓

Layer 5
Argo CD RBAC

        ↓

Layer 6
AppProject boundaries

        ↓

Layer 7
Sync Windows

        ↓

Layer 8
Sync Phases / Waves

        ↓

Layer 9
Kubernetes admission / RBAC / policies

        ↓

Layer 10
Runtime monitoring
```

This is **defense in depth**.

---

# 60. Very important interview question

### What is an Argo CD Sync Window?

A Sync Window is an AppProject-level time policy that controls when matching Applications may synchronize. Windows can be either `allow` or `deny` and may target Applications based on application names, destination namespaces, or destination clusters. ([Argo CD][1])

---

# 61. Allow vs deny

### Allow window

```text
Synchronization allowed
only while window is active.
```

### Deny window

```text
Synchronization prohibited
while window is active.
```

If both active matching types apply:

```text
DENY wins.
```

([Argo CD][1])

---

# 62. Do Sync Windows affect auto-sync?

Yes.

They control automated synchronization and can also constrain manual synchronization. Argo CD provides a manual-sync override option for cases where authorized manual synchronization should remain possible. ([Argo CD][1])

---

# 63. What is `manualSync`?

It permits a manually triggered synchronization to bypass the normal restriction represented by that Sync Window configuration.

Use case:

```text
Normal deployment
      ❌

Emergency operator deployment
      ✅
```

The operator must still have the required Argo CD RBAC permissions. ([Argo CD][1])

---

# 64. What is `syncOverrun`?

It controls whether already-running synchronization can continue when the applicable window state changes.

For example:

```text
17:58 start
18:00 allow window ends
```

With appropriate overrun configuration:

```text
existing deployment
may finish
```

while new deployments remain subject to current window restrictions. ([Argo CD][1])

---

# 65. How do multiple selectors behave?

By default:

```text
applications
namespaces
clusters
```

are effectively:

```text
OR
```

within a window definition.

Current Argo CD also supports using an AND operator when all selected dimensions should match. ([Argo CD][1])

---

# 66. What happens if no Sync Window matches?

Synchronization is unrestricted by Sync Windows.

```text
No matching window
      ↓
Sync allowed
```

([Argo CD][1])

---

# 67. What happens when allow windows exist but none is active?

```text
Sync blocked.
```

This is why allow-window strategies behave like:

```text
"default deny outside approved deployment periods."
```

([Argo CD][1])

---

# 68. Sync Window vs RBAC

Never confuse:

```text
RBAC
=
Is this USER authorized?


Sync Window
=
Is synchronization allowed NOW?
```

You need both conditions to be satisfied for an ordinary manual deployment.

---

# 69. Sync Window vs Sync Wave

Another excellent interview question:

```text
SYNC WINDOW
=
WHEN can the entire synchronization begin?


SYNC WAVE
=
In what order should resources
be synchronized?
```

Example:

```text
Sync Window
10 AM–6 PM
       │
       ▼
deployment permitted
       │
       ▼
PreSync
       │
       ▼
Wave -10
       │
       ▼
Wave 0
       │
       ▼
Wave 10
       │
       ▼
PostSync
```

Completely different purposes.

---

# 70. Sync Window vs Sync Phase

```text
WINDOW
=
calendar/time governance


PHASE
=
deployment lifecycle


WAVE
=
resource ordering
```

Memory trick:

```text
WINDOW = WHEN TODAY?

PHASE  = WHEN IN DEPLOYMENT?

WAVE   = WHAT ORDER?
```

Excellent distinction.

---

# 71. Our production GitOps stack so far

You can now understand this complete pipeline:

```text
                         DEVELOPER

                             │
                             ▼

                         Git Commit

                             │
                             ▼

                         Pull Request

                             │
             ┌───────────────┼────────────────┐
             ▼               ▼                ▼

           Tests          Security         Review

             └───────────────┼────────────────┘
                             ▼

                           Merge

                             │
                             ▼

                        CI Pipeline

                             │
                             ├── Build
                             ├── Scan
                             └── Push ECR

                             │
                             ▼

                    GitOps Repository

                             │
                             ▼

                          ARGO CD

                             │
                             ▼

                          RBAC
                       WHO can act?

                             │
                             ▼

                       AppProject
                  WHAT / FROM / WHERE?

                             │
                             ▼

                       Sync Window
                         WHEN?

                             │
                             ▼

                         PreSync
                             │
                             ▼

                        Sync Waves
                             │
                             ▼

                       Kubernetes

                             │
                             ▼

                        PostSync

                             │
                             ▼

                      Smoke Tests

                             │
                             ▼

                    RELEASE HEALTHY
```

That is no longer just:

```text
kubectl apply deployment.yaml
```

You are now learning **production delivery architecture**.

---

# 72. Never-forget table

| Feature                   | Question                                      |
| ------------------------- | --------------------------------------------- |
| Argo RBAC                 | **Who** may perform the action?               |
| AppProject `sourceRepos`  | **From where** may deployment come?           |
| AppProject `destinations` | **Where** may it deploy?                      |
| Resource restrictions     | **What** may it create?                       |
| Sync Window               | **When** may deployment happen?               |
| Sync Phase                | **When in the lifecycle** does an action run? |
| Sync Wave                 | **In what order** do resources run?           |
| Self Heal                 | What if live state **drifts**?                |
| Prune                     | What if Git **removes** a resource?           |

If you can explain this table in an interview, your Argo CD fundamentals are already well beyond beginner level.

---

# 73. Never-forget production rule

```text
AUTHORIZED
     ≠
ALLOWED RIGHT NOW
```

An engineer may have:

```text
correct identity        ✅
correct RBAC            ✅
correct AppProject      ✅
correct Git repository  ✅
correct destination     ✅
```

and deployment can still be:

```text
BLOCKED
```

because:

```text
Sync Window = closed
```

That's intentional production governance.

---

# 74. Lesson 14.14 complete

Our Module 14 progress is now:

```text
Module 14 — GitOps with Argo CD

14.1  GitOps Mental Model                       ✅
14.2  Argo CD Architecture                      ✅
14.3  Installation                              ✅
14.4  Applications                              ✅
14.5  Automated Reconciliation                  ✅
14.6  Repository Structure                      ✅
14.7  Helm + Argo CD                            ✅
14.8  Kustomize + Argo CD                       ✅
14.9  Production Repository Patterns            ✅
14.10 Advanced Application Management           ✅
14.11 Hooks, Phases & Sync Waves                ✅
14.12 Drift, Self-Healing & Sync Policies       ✅
14.13 AppProject, RBAC & Multi-Team Security    ✅
14.14 Sync Windows & Deployment Governance      ✅
```

## Next — Lesson 14.15

### **Argo CD ApplicationSet — Managing Hundreds of Applications & Clusters**

This is a major lesson.

We are about to solve this problem:

```text
Today:

Application
todo-dev

Application
todo-staging

Application
todo-production
```

Imagine instead:

```text
100 microservices

× 3 environments

× 5 Kubernetes clusters

=
potentially hundreds or thousands
of Argo CD Applications
```

We obviously do **not** want to manually write:

```text
application-1.yaml
application-2.yaml
application-3.yaml
...
application-500.yaml
```

So next we'll learn:

```text
                    ApplicationSet

                          │
           ┌──────────────┼──────────────┐
           ▼              ▼              ▼

       Git Generator   List Generator  Cluster Generator
           │              │              │
           └──────────────┼──────────────┘
                          ▼

                 Generate Applications

                          │
        ┌─────────────────┼─────────────────┐
        ▼                 ▼                 ▼

      DEV              STAGING            PROD

        │                 │                 │
        ▼                 ▼                 ▼

   Cluster A          Cluster B          Cluster C
```

We'll cover **List, Git Directory, Git File, Cluster, Matrix and Merge generators, multi-cluster deployments, environment generation, Go templating, production repository structures, deletion safety, progressive sync concepts, hands-on labs, and the common ApplicationSet disasters you must avoid.**

[1]: https://argo-cd.readthedocs.io/en/stable/user-guide/sync_windows/ "Sync Windows - Argo CD - Declarative GitOps CD for Kubernetes"
[2]: https://argo-cd.readthedocs.io/en/latest/user-guide/commands/argocd_proj_windows_add/ "argocd proj windows add Command Reference - Argo CD - Declarative GitOps CD for Kubernetes"
[3]: https://argo-cd.readthedocs.io/en/latest/operator-manual/project-specification/ "Project Specification Reference - Argo CD - Declarative GitOps CD for Kubernetes"
