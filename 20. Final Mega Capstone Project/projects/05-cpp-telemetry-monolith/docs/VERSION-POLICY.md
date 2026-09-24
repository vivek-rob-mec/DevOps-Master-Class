# Runtime and dependency version policy

Defaults were reviewed on **2026-08-16** against upstream lifecycle and release documentation. They are a dated baseline, not a reason to skip a fresh review before deployment.

| Component | Template baseline | Why |
|---|---|---|
| Node.js build/runtime | 24 LTS | Supported LTS; Node 20 reached end-of-life on 2026-03-24 |
| React | 19.2.7 | Current patched React 19.2 release at review time |
| Next.js | 16.2.11 | Active-LTS security release named by the Next.js team in July 2026 |
| Vite | 8.1.x | Current regularly patched Vite line at review time |
| Spring Boot | 4.1.0 | Current stable line at review time; Java 21 is within its supported Java range |
| Amazon EKS | Kubernetes 1.36 | Standard support scheduled through 2027-08-02 |
| Terraform AWS/EKS modules | AWS provider 6.x, EKS module 21.x | Current compatible major contracts at review time |
| Helm | 4.x | Current stable major; Helm 3 is approaching end-of-life |

Authoritative lifecycle references:

- <https://nodejs.org/en/about/previous-releases>
- <https://nextjs.org/blog>
- <https://react.dev/versions>
- <https://vite.dev/releases>
- <https://spring.io/projects/spring-boot/>
- <https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html>
- <https://github.com/terraform-aws-modules/terraform-aws-eks>
- <https://helm.sh/blog/helm-v3-end-of-life/>

## Required maintenance workflow

1. Use Renovate or Dependabot to propose small, scheduled updates to lockfiles, actions, images, charts, providers, and modules.
2. Review upstream security and breaking-change notes; do not merge version-only changes blindly.
3. Rebuild, run unit/integration/contract tests, render manifests, scan artifacts, and execute smoke tests.
4. Promote one immutable image digest through environments; do not rebuild per environment.
5. Record exceptions with owner, risk, compensating controls, expiry date, and upgrade plan.
6. Pin container image digests and GitHub Actions commit SHAs in a real production repository after the learning template has been forked.
