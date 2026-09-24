# Adapt the shared method to other stacks

Keep the release identity, environment promotion, operations contract, and verification steps. Change the application build/test adapter and resource requirements. Use the linked business applications to extend this delivery exercise.

| Stack | Real application build/test adapter | Deployment adaptation | Existing example |
|---|---|---|---|
| Python Flask/Django/FastAPI | Lock dependencies; run pytest/framework tests | Gunicorn WSGI or supported ASGI server; migrations as an explicit job | [Python](../../07-python-learning-monolith/README.md), [Django workers](../../14-django-logistics-workers/README.md) |
| Node.js/Express/NestJS | `npm ci`, tests, production compile if applicable | Production process; exclude dev dependencies; handle SIGTERM | [Node](../../06-node-helpdesk-monolith/README.md), [NestJS](../../12-typescript-nestjs-angular-saas/README.md) |
| Java/Spring Boot | Maven/Gradle wrapper with tests and verification | Executable JAR in JRE image; map Actuator readiness/liveness; size JVM for container limit | [Java](../../08-java-supply-chain-monolith/README.md) |
| Go | `go mod download`, `go test ./...`, static build where possible | Small binary; dependency deadlines; graceful shutdown | [Go](../../10-go-url-shortener/README.md) |
| .NET/ASP.NET Core | `dotnet restore --locked-mode`, `dotnet test`, publish | ASP.NET runtime image; health checks; migrations as a job | [.NET](../../13-dotnet-insurance-monolith/README.md) |
| PHP/Laravel/Symfony | Composer install from lockfile, PHPUnit, asset build | PHP-FPM behind a web server or an approved application server; writable cache directories | [PHP](../../04-php-inventory-monolith/README.md) |
| Ruby/Rails | Bundler lockfile, Rails tests, asset precompile | Puma; separate jobs/workers; bounded DB pools and migration stage | [Rails](../../15-rails-subscription-billing/README.md) |
| React/Vue/Angular SPA | Lockfile install, unit tests, production bundle | Serve static assets via CDN/object storage or web-server container; configure SPA fallback and cache headers | [MERN](../../09-mern-team-collaboration/README.md), [Angular](../../12-typescript-nestjs-angular-saas/README.md) |
| Next.js/server rendering | Lockfile install, tests, framework production build | Node runtime or supported managed host; server-side secrets never go into browser bundles | [Booking](../../03-node-booking-microservices/README.md) |
| Rust | `cargo test --locked`, release build | Minimal runtime with required native libraries; graceful shutdown | [Rust](../../17-rust-payment-risk-service/README.md) |
| C++ | CMake configure/build, CTest, sanitizer checks | Package runtime libraries; verify ABI and native dependencies | [C++](../../05-cpp-telemetry-monolith/README.md) |

Commands in this table describe adaptation steps, not files already supplied in every project. Use each application's actual package scripts and test layout.

## Workload boundaries

For a monolith, publish one deployable application image. A separate static frontend can have its own artifact and CDN release. For microservices, give each service its own contract, release record, ownership, and independently selected version. A language matrix demonstrates equivalent implementations; it is not a reason to release every service together.

Workers need queue-based readiness and graceful drain, queue-lag alerts, idempotency, and poison-message handling. They should not inherit a web Service/HTTP readiness probe unless they expose an appropriate administration endpoint. Scheduled jobs need Job/CronJob completion and retry semantics. Serverless, data pipelines, and GPU workloads need their platform's release contracts.

## Data and configuration

Use managed database/service endpoints supplied at runtime. Add a secret-manager integration and narrowly scoped network access. Keep migration permissions separate from application permissions. Run schema changes once through an observable migration job, with an expand/migrate/contract rollout: first add compatible structures, deploy compatible readers/writers, backfill, verify, then remove old structures in a later release. Application rollback does not undo a destructive schema change.

For static frontends, build-time environment substitution can force rebuilding per environment. To preserve promotion of one artifact, provide a public runtime configuration document or platform-supported equivalent. Never put secrets into that document. Check browser API compatibility during promotion.

Change readiness to reflect whether the service can do useful work, using bounded checks and an explicit dependency policy. Keep external dependency failures out of liveness checks to prevent restart storms. Extend the generic smoke check with a safe, representative business transaction and cleanup procedure.
