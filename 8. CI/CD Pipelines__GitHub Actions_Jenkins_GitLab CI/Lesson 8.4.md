# Lesson 8.4 — Jenkins Fundamentals Masterclass

# Controller, Agents, Jenkinsfile, Declarative Pipeline, Stages, Steps, Environment, Parameters, Credentials, Tools, Workspace, Artifacts, Post Actions, and Approvals

Jenkins is an automation server that can be used as a CI server or as a full continuous delivery hub for building, testing, deploying, and automating projects. ([Jenkins][1])

In Module 8, Jenkins is important because you already used Jenkins in your Todo-App-DevOps project for:

```text id="b4o4uq"
artifact deployment
atomic release folders
current symlink switch
PM2 restart
runtime validation
rollback
```

Now we will formalize Jenkins properly.

---

# 1. Jenkins Mental Model

Jenkins has three main parts:

```text id="7yd9nf"
Jenkins controller
  manages jobs, plugins, credentials, build history, UI

Jenkins agent
  executes pipeline work

Jenkinsfile
  pipeline-as-code file stored in source control
```

Simple flow:

```text id="sb5pwi"
Developer pushes code
  ↓
Jenkins detects change
  ↓
Jenkins controller schedules job
  ↓
Agent gets workspace
  ↓
Jenkinsfile runs stages
  ↓
Tests/build/deploy happen
  ↓
Artifacts/logs/status are recorded
```

Professional rule:

```text id="6vr5vy"
The Jenkins controller should orchestrate; agents should execute heavy work.
```

Do not overload the controller with heavy builds.

---

# 2. Controller vs Agent

## Jenkins Controller

The controller handles:

```text id="vdqp9m"
web UI
job configuration
pipeline scheduling
credentials management
plugin management
build history
agent coordination
```

## Jenkins Agent

The agent handles:

```text id="rns7o5"
checkout
npm ci
tests
Docker build
security scans
deployment scripts
artifact creation
```

Bad:

```text id="x5pwg3"
run every Docker build on Jenkins controller
```

Good:

```text id="atlawc"
run build jobs on dedicated Linux/Docker agents
```

Professional rule:

```text id="9yraqb"
Treat Jenkins agents like disposable CI workers.
```

---

# 3. Jenkinsfile

A Jenkinsfile is the pipeline definition stored in your repository.

Jenkins Pipeline as Code stores pipeline logic in source control, commonly in a file named `Jenkinsfile` at the repository root. ([Jenkins][2])

Example:

```groovy id="0d7pql"
pipeline {
  agent any

  stages {
    stage('Test') {
      steps {
        sh 'npm test'
      }
    }
  }
}
```

Why Jenkinsfile matters:

```text id="5ckhmg"
pipeline is versioned
pipeline changes go through Git
team can review CI/CD logic
reproducibility improves
manual UI job drift is reduced
```

Professional rule:

```text id="t5pqcu"
Prefer pipeline-as-code over manually configured freestyle jobs.
```

---

# 4. Declarative vs Scripted Pipeline

Jenkins supports two Pipeline syntaxes:

```text id="1g6llu"
Declarative Pipeline
Scripted Pipeline
```

Jenkins docs explain that Declarative Pipeline is designed to make Pipeline code easier to write and read, while Scripted Pipeline is more flexible and Groovy-based. ([Jenkins][3])

For this course:

```text id="kme3gb"
Use Declarative Pipeline by default.
Use Scripted blocks only when necessary.
```

Declarative example:

```groovy id="uk2c37"
pipeline {
  agent any

  stages {
    stage('Build') {
      steps {
        sh 'echo build'
      }
    }
  }
}
```

Scripted-style block inside Declarative:

```groovy id="zds63x"
script {
  def tag = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
  echo "Tag: ${tag}"
}
```

Professional rule:

```text id="2zrpwy"
Keep Jenkinsfiles readable. Do not turn every pipeline into complex Groovy code.
```

---

# 5. Core Jenkins Pipeline Structure

Basic Declarative Pipeline:

```groovy id="56u3q8"
pipeline {
  agent any

  environment {
    APP_DIR = '05-application-runtime/demo-node-api'
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Test') {
      steps {
        dir("${APP_DIR}") {
          sh 'npm test'
        }
      }
    }
  }

  post {
    always {
      echo 'Pipeline finished'
    }
  }
}
```

Core blocks:

```text id="s10i4v"
pipeline:
  root block

agent:
  where pipeline runs

environment:
  variables

stages:
  list of phases

stage:
  one visible phase

steps:
  commands/actions

post:
  cleanup/status actions after run
```

Jenkins Pipeline syntax uses stages and steps; steps are the basic building blocks that tell Jenkins what to do. ([Jenkins][4])

---

# 6. Stages and Steps

## Stage

A stage is a visible pipeline phase:

```groovy id="k5jz5f"
stage('Test') {
  steps {
    sh 'npm test'
  }
}
```

Common stages:

```text id="pm39xp"
Checkout
Setup
Install
Test
Build
Scan
Publish
Deploy
Verify
Rollback
```

## Step

A step is an executable action:

```groovy id="owgkrt"
sh 'npm ci'
archiveArtifacts artifacts: 'reports/*.json'
input message: 'Deploy to production?'
```

Professional rule:

```text id="rap70t"
Stages should tell a story. Steps should do focused work.
```

---

# 7. Agent

Simple:

```groovy id="bzohmo"
agent any
```

Specific label:

```groovy id="8f5dib"
agent {
  label 'linux-docker'
}
```

No global agent, choose per stage:

```groovy id="r7u0tm"
pipeline {
  agent none

  stages {
    stage('Test') {
      agent { label 'nodejs' }
      steps {
        sh 'npm test'
      }
    }

    stage('Docker Build') {
      agent { label 'docker' }
      steps {
        sh 'docker build -t app .'
      }
    }
  }
}
```

Professional rule:

```text id="xg6qgn"
Use agent labels to route jobs to machines with the right tools.
```

Examples:

```text id="g4gloo"
linux
nodejs
docker
terraform
ansible
aws
gpu
```

---

# 8. Environment Variables

Global environment:

```groovy id="qds2qp"
environment {
  APP_DIR = '05-application-runtime/demo-node-api'
  NODE_ENV = 'test'
}
```

Stage-level environment:

```groovy id="4aosg1"
stage('Test') {
  environment {
    LOG_LEVEL = 'debug'
  }
  steps {
    sh 'echo $LOG_LEVEL'
  }
}
```

Jenkins docs show environment variables can be set globally or per stage; stage-level variables apply only to that stage. ([Jenkins][5])

Professional rule:

```text id="0du391"
Use environment for non-secret config. Use credentials for secrets.
```

---

# 9. Parameters

Parameters allow manual input at build start.

Example:

```groovy id="yj1i4l"
parameters {
  string(name: 'BASE_VERSION', defaultValue: '0.8.0', description: 'Base version')
  choice(name: 'CHANNEL', choices: ['dev', 'rc', 'stable'], description: 'Release channel')
  booleanParam(name: 'PUSH_IMAGE', defaultValue: false, description: 'Push image to registry?')
}
```

Use:

```groovy id="sf1wbe"
echo "Version: ${params.BASE_VERSION}"
echo "Channel: ${params.CHANNEL}"
```

Good for:

```text id="ysso9e"
manual release version
target environment
rollback version
push image toggle
deployment approval context
```

Professional rule:

```text id="2kv9or"
Parameters should control pipeline behavior, not hide business logic.
```

---

# 10. Credentials

Jenkins credentials should be stored in Jenkins Credentials, not in Git.

Jenkins docs describe adding credentials through Jenkins credentials management, and Declarative Pipeline supports using a `credentials()` helper in the `environment` directive for secret text, username/password, and secret files. ([Jenkins][6])

Example secret text:

```groovy id="l4zvix"
environment {
  GHCR_TOKEN = credentials('ghcr-token')
}
```

Username/password:

```groovy id="bqubos"
environment {
  GHCR_CREDS = credentials('ghcr-username-password')
}
```

Then Jenkins exposes:

```text id="7tuvti"
GHCR_CREDS
GHCR_CREDS_USR
GHCR_CREDS_PSW
```

Use with Docker login:

```groovy id="kf869d"
sh '''
  echo "$GHCR_CREDS_PSW" | docker login ghcr.io -u "$GHCR_CREDS_USR" --password-stdin
'''
```

Alternative with `withCredentials`:

```groovy id="rjf41n"
withCredentials([string(credentialsId: 'ghcr-token', variable: 'GHCR_TOKEN')]) {
  sh '''
    echo "$GHCR_TOKEN" | docker login ghcr.io -u "$GITHUB_USERNAME" --password-stdin
  '''
}
```

The Credentials Binding plugin provides Pipeline-compatible steps that bind credentials to environment variables during builds. ([Jenkins][7])

Professional rules:

```text id="cer977"
Never hardcode secrets in Jenkinsfile.
Never echo secrets.
Use least-privilege credentials.
Prefer short-lived/cloud role credentials where possible.
```

---

# 11. Tools

Jenkins can manage tools such as Node.js, Maven, JDK, etc.

Example:

```groovy id="150iw8"
tools {
  nodejs 'node-js-22'
}
```

Then:

```groovy id="rhtzoj"
sh 'node --version'
sh 'npm --version'
```

In your previous Jenkins setup, you had a tool like:

```text id="ag8e6j"
node-js_25
```

For this module, use whatever is configured in your Jenkins:

```text id="yqny2f"
node-js_25
node-js-22
node-22
```

Professional rule:

```text id="rlonqb"
Pin and document Jenkins tool names. Pipelines fail when tool names drift.
```

---

# 12. Workspace

Each Jenkins job runs in a workspace.

Workspace contains:

```text id="x1z5xc"
checked-out source code
temporary files
build outputs
test reports
scripts
artifacts before archiving
```

Useful commands:

```groovy id="99xy41"
sh '''
  pwd
  ls -la
  git status || true
'''
```

Clean workspace:

```groovy id="92r9td"
post {
  always {
    cleanWs()
  }
}
```

Professional caution:

```text id="83ej0z"
Do not assume workspace is clean unless you clean it or use fresh agents.
```

---

# 13. Artifacts in Jenkins

Archive artifacts:

```groovy id="hu3c59"
archiveArtifacts artifacts: 'reports/**/*.json', allowEmptyArchive: true
```

JUnit test reports:

```groovy id="2it0xy"
junit 'test-results/**/*.xml'
```

Use artifacts for:

```text id="x82f9j"
test reports
coverage reports
release metadata
SBOM
scan reports
deployment reports
logs
```

Professional rule:

```text id="500dvr"
Pipeline logs are not enough. Archive structured evidence.
```

---

# 14. Post Actions

`post` runs after stages.

Example:

```groovy id="621ow9"
post {
  always {
    echo 'Always runs'
  }

  success {
    echo 'Pipeline succeeded'
  }

  failure {
    echo 'Pipeline failed'
  }

  cleanup {
    cleanWs()
  }
}
```

Use `post` for:

```text id="q97nfs"
archive reports
publish test results
send notifications
cleanup workspace
debug on failure
```

Professional rule:

```text id="pzil1f"
Always preserve useful failure evidence before cleanup.
```

---

# 15. Input Approval

Jenkins can pause for human approval using the `input` step. The Jenkins input step pauses Pipeline execution and lets a user proceed or abort. ([Jenkins][8])

Example:

```groovy id="fg3r7w"
stage('Approve Production') {
  steps {
    input message: 'Deploy to production?', ok: 'Deploy'
  }
}
```

With parameter:

```groovy id="v39c4h"
def approval = input(
  message: 'Approve production deployment?',
  parameters: [
    string(name: 'CHANGE_TICKET', defaultValue: '', description: 'Change ticket')
  ]
)
```

Professional rule:

```text id="gftwkg"
Approval should approve a specific immutable artifact, not vague source code.
```

Bad:

```text id="2xef4h"
Approve deploy latest?
```

Good:

```text id="32s58d"
Approve ghcr.io/user/demo-node-api:0.8.0-a1b2c3d?
```

---

# 16. Hands-On — Create Jenkins Lesson Directory

Run:

```bash id="co3i6j"
cd ~/devops-masterclass/08-cicd-pipelines

mkdir -p jenkins/{notes,pipelines,scripts,reports,runbooks,examples}
```

---

# 17. Create Jenkins Fundamentals Notes

Create:

```bash id="kwq1oy"
nano jenkins/notes/jenkins-fundamentals.md
```

Paste:

````markdown id="7gly6w"
# Jenkins Fundamentals

## Core Components

- Jenkins controller: UI, scheduling, credentials, plugins, job history
- Jenkins agent: executes pipeline work
- Jenkinsfile: pipeline-as-code file stored in source control

## Pipeline Types

- Declarative Pipeline: recommended default
- Scripted Pipeline: flexible Groovy-based syntax

## Core Blocks

```groovy
pipeline {
  agent any

  environment {
    APP_DIR = '05-application-runtime/demo-node-api'
  }

  stages {
    stage('Test') {
      steps {
        sh 'npm test'
      }
    }
  }

  post {
    always {
      echo 'done'
    }
  }
}
````

## Production Rules

* Prefer Pipeline as Code.
* Run heavy work on agents, not controller.
* Use credentials store for secrets.
* Do not echo secrets.
* Archive release evidence.
* Use input approval for production.
* Approve immutable artifacts.
* Clean workspace carefully.
* Keep Jenkinsfiles readable.

````

---

# 18. Create Basic Jenkinsfile for Your Node App

Create:

```bash id="i7h9f1"
nano jenkins/pipelines/Jenkinsfile.node-basic
````

Paste:

```groovy id="wvze7v"
pipeline {
  agent any

  environment {
    APP_DIR = '05-application-runtime/demo-node-api'
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Show Context') {
      steps {
        sh '''
          echo "Workspace: $WORKSPACE"
          echo "Build number: $BUILD_NUMBER"
          echo "Job name: $JOB_NAME"
          pwd
          ls -la
          git rev-parse --short HEAD || true
        '''
      }
    }

    stage('Install Dependencies') {
      steps {
        dir("${APP_DIR}") {
          sh '''
            node --version
            npm --version
            npm ci
          '''
        }
      }
    }

    stage('Test') {
      steps {
        dir("${APP_DIR}") {
          sh 'npm test'
        }
      }
    }
  }

  post {
    always {
      echo 'Basic Node.js Jenkins pipeline finished.'
    }

    success {
      echo 'Basic Node.js Jenkins pipeline succeeded.'
    }

    failure {
      echo 'Basic Node.js Jenkins pipeline failed.'
    }
  }
}
```

If your Jenkins requires a configured NodeJS tool, use:

```groovy id="p76qjx"
tools {
  nodejs 'node-js_25'
}
```

Add it under `agent any` if needed:

```groovy id="fm5sen"
pipeline {
  agent any

  tools {
    nodejs 'node-js_25'
  }

  ...
}
```

---

# 19. Create Parameterized Jenkinsfile

Create:

```bash id="ofkkyw"
nano jenkins/pipelines/Jenkinsfile.parameterized
```

Paste:

```groovy id="cez15x"
pipeline {
  agent any

  parameters {
    string(name: 'BASE_VERSION', defaultValue: '0.8.0', description: 'Base semantic version')
    choice(name: 'CHANNEL', choices: ['dev', 'rc', 'stable'], description: 'Release channel')
    booleanParam(name: 'RUN_DOCKER_BUILD', defaultValue: false, description: 'Build Docker image?')
  }

  environment {
    APP_DIR = '05-application-runtime/demo-node-api'
    IMAGE_NAME = 'demo-node-api'
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Compute Version') {
      steps {
        script {
          def shortSha = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
          def version = params.BASE_VERSION

          if (params.CHANNEL == 'dev') {
            version = "${params.BASE_VERSION}-dev"
          } else if (params.CHANNEL == 'rc') {
            version = "${params.BASE_VERSION}-rc.1"
          }

          env.SHORT_SHA = shortSha
          env.VERSION = version
          env.DEPLOY_TAG = "${version}-${shortSha}"

          echo "Deploy tag: ${env.DEPLOY_TAG}"
        }
      }
    }

    stage('Install Dependencies') {
      steps {
        dir("${APP_DIR}") {
          sh 'npm ci'
        }
      }
    }

    stage('Test') {
      steps {
        dir("${APP_DIR}") {
          sh 'npm test'
        }
      }
    }

    stage('Docker Build') {
      when {
        expression { return params.RUN_DOCKER_BUILD }
      }
      steps {
        dir("${APP_DIR}") {
          sh '''
            VERSION="$DEPLOY_TAG" ./scripts/docker-build.sh
          '''
        }
      }
    }

    stage('Create CI Report') {
      steps {
        sh '''
          mkdir -p 08-cicd-pipelines/jenkins/reports

          cat > 08-cicd-pipelines/jenkins/reports/jenkins-ci-report.json <<EOF
          {
            "job_name": "$JOB_NAME",
            "build_number": "$BUILD_NUMBER",
            "commit_sha": "$GIT_COMMIT",
            "deploy_tag": "$DEPLOY_TAG",
            "test_status": "passed",
            "docker_build": "${RUN_DOCKER_BUILD}",
            "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
          }
          EOF

          cat 08-cicd-pipelines/jenkins/reports/jenkins-ci-report.json
        '''
      }
    }
  }

  post {
    always {
      archiveArtifacts artifacts: '08-cicd-pipelines/jenkins/reports/*.json', allowEmptyArchive: true
    }

    success {
      echo "Pipeline succeeded for ${env.DEPLOY_TAG}"
    }

    failure {
      echo 'Pipeline failed.'
    }
  }
}
```

Note:

```text id="1l4lv0"
RUN_DOCKER_BUILD is a Jenkins parameter; inside shell it may not automatically appear as an env var depending on Jenkins behavior/plugins. For simplicity, the report uses it as shell text, but in production prefer writing values from Groovy or explicit env.
```

A safer report creation pattern is:

```groovy id="8wad2a"
writeFile file: 'report.json', text: groovy.json.JsonOutput.toJson([docker_build: params.RUN_DOCKER_BUILD])
```

We will improve that in production pipeline lessons.

---

# 20. Create Jenkins Credentials Example

Create:

```bash id="1nkobl"
nano jenkins/pipelines/Jenkinsfile.credentials-example
```

Paste:

```groovy id="p23aua"
pipeline {
  agent any

  environment {
    GITHUB_USERNAME = 'YOUR_GITHUB_USERNAME'
  }

  stages {
    stage('Use GHCR Token Safely') {
      steps {
        withCredentials([string(credentialsId: 'ghcr-token', variable: 'GHCR_TOKEN')]) {
          sh '''
            echo "Logging into GHCR..."
            echo "$GHCR_TOKEN" | docker login ghcr.io -u "$GITHUB_USERNAME" --password-stdin
            echo "Login command completed."
          '''
        }
      }
    }
  }

  post {
    always {
      sh 'docker logout ghcr.io || true'
    }
  }
}
```

Important:

```text id="bckfik"
Create Jenkins credential ID: ghcr-token
Type: Secret text
Value: GHCR token
```

Never commit the token itself.

---

# 21. Create Jenkins Input Approval Example

Create:

```bash id="s8o4t7"
nano jenkins/pipelines/Jenkinsfile.input-approval
```

Paste:

```groovy id="l24fng"
pipeline {
  agent any

  parameters {
    string(name: 'IMAGE_REF', defaultValue: 'ghcr.io/user/demo-node-api:0.8.0-dev-a1b2c3d', description: 'Immutable image ref')
    string(name: 'ROLLBACK_VERSION', defaultValue: '0.7.0-previous', description: 'Previous known-good version')
  }

  stages {
    stage('Validate Artifact') {
      steps {
        script {
          if (params.IMAGE_REF.endsWith(':latest')) {
            error('Refusing to deploy latest')
          }

          echo "Artifact: ${params.IMAGE_REF}"
          echo "Rollback: ${params.ROLLBACK_VERSION}"
        }
      }
    }

    stage('Approve Production') {
      steps {
        input message: "Approve production deployment of ${params.IMAGE_REF}?", ok: 'Deploy'
      }
    }

    stage('Deploy Placeholder') {
      steps {
        sh '''
          echo "Deploying approved artifact:"
          echo "${IMAGE_REF}"
          echo "Rollback version:"
          echo "${ROLLBACK_VERSION}"
        '''
      }
    }
  }
}
```

This teaches production approval.

---

# 22. Create Jenkins Shared Concept Notes

Create:

```bash id="f1f93a"
nano jenkins/notes/jenkins-vs-github-actions.md
```

Paste:

```markdown id="zmj0kb"
# Jenkins vs GitHub Actions Mapping

| Concept | GitHub Actions | Jenkins |
|---|---|---|
| Pipeline file | `.github/workflows/*.yml` | `Jenkinsfile` |
| Worker | runner | agent/node |
| Workflow | workflow | pipeline |
| Job | job | stage/pipeline branch |
| Step | step | step |
| Secrets | GitHub Secrets | Jenkins Credentials |
| Manual approval | Environment approval | `input` step |
| Artifact upload | `actions/upload-artifact` | `archiveArtifacts` |
| Test report | uploaded artifact/test action | `junit` |
| Permissions | `permissions:` | Jenkins RBAC/credentials |
| Tool install | setup actions | Jenkins tools/global config |

## Important Difference

GitHub Actions is usually repository-native and managed.

Jenkins is self-managed and highly customizable.

Jenkins gives more control but needs more maintenance.
```

---

# 23. Jenkins Local Syntax/Lint Reality

Jenkinsfile validation usually happens through Jenkins itself.

Jenkins provides a Pipeline syntax/snippet generator and development tools for Pipeline validation. The Jenkins docs mention the Pipeline linter endpoint under `/pipeline-model-converter/validate` for validating Jenkinsfiles. ([Jenkins][9])

If Jenkins is running:

```bash id="xpq23x"
curl -X POST \
  -u "USER:TOKEN" \
  -F "jenkinsfile=<jenkins/pipelines/Jenkinsfile.node-basic" \
  "http://JENKINS_URL/pipeline-model-converter/validate"
```

For now, we create a basic local structural validator.

Create:

```bash id="2t3kdk"
nano jenkins/scripts/validate-jenkinsfiles.sh
```

Paste:

```bash id="d71h41"
#!/usr/bin/env bash
set -euo pipefail

DIR="${DIR:-jenkins/pipelines}"

echo "===== Validate Jenkinsfiles Basic Structure ====="

if [ ! -d "$DIR" ]; then
  echo "ERROR: directory not found: $DIR" >&2
  exit 1
fi

FAILED=0

for file in "$DIR"/Jenkinsfile*; do
  [ -f "$file" ] || continue

  echo "Checking: $file"

  if ! grep -q "pipeline" "$file"; then
    echo "  ERROR: missing pipeline block"
    FAILED=1
  fi

  if ! grep -q "stages" "$file"; then
    echo "  ERROR: missing stages block"
    FAILED=1
  fi

  if ! grep -q "stage(" "$file"; then
    echo "  ERROR: missing stage definitions"
    FAILED=1
  fi

  if ! grep -q "steps" "$file"; then
    echo "  WARNING: no steps block found"
  fi
done

if [ "$FAILED" -ne 0 ]; then
  echo "Validation failed."
  exit 1
fi

echo "Basic Jenkinsfile validation passed."
```

Make executable:

```bash id="2wb2bk"
chmod +x jenkins/scripts/validate-jenkinsfiles.sh
```

Run:

```bash id="h8865o"
./jenkins/scripts/validate-jenkinsfiles.sh
```

---

# 24. Create Jenkins Troubleshooting Runbook

Create:

```bash id="h634r0"
nano jenkins/runbooks/jenkins-troubleshooting.md
```

Paste:

````markdown id="6xzrfm"
# Jenkins Troubleshooting Runbook

## Pipeline does not start

Check:

- webhook configured
- multibranch scan ran
- branch contains Jenkinsfile
- Jenkinsfile path correct
- job enabled
- credentials for Git checkout valid

## Agent offline

Check:

- agent connection
- labels
- disk space
- Java version
- network connectivity
- executor availability

## Tool not found

Error examples:

```text
node: command not found
npm: command not found
docker: command not found
````

Check:

* Jenkins tool configuration
* agent PATH
* Docker installed on agent
* user permission to Docker socket
* stage agent label

## npm ci fails

Check:

```bash
cd 05-application-runtime/demo-node-api
npm ci
```

Possible causes:

* wrong working directory
* missing package-lock
* Node version mismatch
* private registry auth missing

## Docker permission denied

Check:

```bash
docker ps
groups
ls -l /var/run/docker.sock
```

Possible causes:

* Jenkins user not in docker group
* Docker not installed on agent
* rootless Docker mismatch
* agent label wrong

## Credentials not found

Check:

* credential ID spelling
* credential scope
* folder-level credential visibility
* plugin installed
* Jenkinsfile uses correct binding

## Input approval stuck

Check:

* build page
* input step sidebar
* user has permission to approve
* pipeline is not waiting on another executor

## Archive artifacts missing

Check:

* file exists before archive
* path is relative to workspace
* allowEmptyArchive setting

````

---

# 25. Create Jenkins Best Practices Notes

Create:

```bash id="lviq3o"
nano jenkins/notes/jenkins-best-practices.md
````

Paste:

```markdown id="5z0b9c"
# Jenkins Best Practices

## Architecture

- Keep controller lightweight.
- Run builds on agents.
- Use labels for specialized agents.
- Keep plugins updated but tested.
- Back up Jenkins home.
- Use RBAC and least privilege.

## Pipeline

- Use Jenkinsfile.
- Keep Jenkinsfile readable.
- Use Declarative Pipeline by default.
- Archive structured evidence.
- Use `post` for cleanup and reporting.
- Avoid excessive Groovy complexity.

## Security

- Store secrets in Jenkins Credentials.
- Do not echo secrets.
- Use least-privilege credentials.
- Restrict who can edit Jenkinsfiles for production jobs.
- Use approval gates for production.
- Do not run untrusted PRs with production credentials.

## Agents

- Use clean workspaces.
- Avoid persistent state assumptions.
- Monitor disk usage.
- Install required tools predictably.
- Separate Docker-capable agents from general agents if needed.

## Deployments

- Approve immutable artifacts.
- Do not deploy latest.
- Verify deployment health.
- Record rollback version.
- Archive deployment reports.
```

---

# 26. Update Makefile

Open:

```bash id="o6cxfa"
cd ~/devops-masterclass/08-cicd-pipelines

nano Makefile
```

Add:

```Makefile id="jyo024"
.PHONY: validate-jenkins list-jenkins

validate-jenkins:
	./jenkins/scripts/validate-jenkinsfiles.sh

list-jenkins:
	find jenkins -type f | sort
```

Run:

```bash id="mg83ig"
make validate-jenkins
make list-jenkins
```

---

# 27. Optional — Copy Jenkinsfile to Repo Root

If you want Jenkins to detect the basic pipeline from repo root:

```bash id="vv6roq"
cd ~/devops-masterclass

cp 08-cicd-pipelines/jenkins/pipelines/Jenkinsfile.node-basic Jenkinsfile
```

Then commit it.

But if you already have a Jenkinsfile for another pipeline, do not overwrite it.

Safer:

```bash id="2sp1gb"
cp 08-cicd-pipelines/jenkins/pipelines/Jenkinsfile.node-basic Jenkinsfile.module8-basic
```

Then configure Jenkins job to use:

```text id="3vyxc3"
Jenkinsfile.module8-basic
```

or:

```text id="d2yx3h"
08-cicd-pipelines/jenkins/pipelines/Jenkinsfile.node-basic
```

as script path.

---

# 28. Practical Lab

Run:

```bash id="xvh7i2"
cd ~/devops-masterclass/08-cicd-pipelines

./jenkins/scripts/validate-jenkinsfiles.sh
make validate-jenkins
```

List files:

```bash id="vga97v"
find jenkins -type f | sort
```

Expected:

```text id="m3o62l"
jenkins/notes/jenkins-fundamentals.md
jenkins/notes/jenkins-vs-github-actions.md
jenkins/notes/jenkins-best-practices.md
jenkins/pipelines/Jenkinsfile.node-basic
jenkins/pipelines/Jenkinsfile.parameterized
jenkins/pipelines/Jenkinsfile.credentials-example
jenkins/pipelines/Jenkinsfile.input-approval
jenkins/runbooks/jenkins-troubleshooting.md
jenkins/scripts/validate-jenkinsfiles.sh
```

Run a Jenkins job using `Jenkinsfile.node-basic`.

In Jenkins UI:

```text id="8bmgkt"
New Item
  -> Pipeline
  -> Pipeline from SCM
  -> Git repository URL
  -> Script Path:
     08-cicd-pipelines/jenkins/pipelines/Jenkinsfile.node-basic
```

Expected stages:

```text id="ez2bpu"
Checkout
Show Context
Install Dependencies
Test
```

---

# 29. Common Jenkins Errors

## `node: command not found`

Cause:

```text id="hmzlp1"
agent does not have Node.js or Jenkins tool not configured
```

Fix:

```groovy id="0u4nv0"
tools {
  nodejs 'node-js_25'
}
```

or install Node on agent.

---

## `docker: permission denied`

Cause:

```text id="p6lrzs"
Jenkins user cannot access Docker socket
```

Fix carefully:

```bash id="qu2h24"
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins
```

Security warning:

```text id="2z7v1w"
Docker socket access is root-equivalent. Only trusted Jenkins jobs should run on Docker-capable agents.
```

---

## `credentials not found`

Cause:

```text id="5fcysd"
wrong credentialsId
credential scope not visible
plugin missing
folder restriction
```

Fix:

```text id="c13r7j"
Manage Jenkins
  -> Credentials
  -> verify ID
```

---

## `No such DSL method`

Cause:

```text id="ycifge"
plugin missing or syntax wrong
```

Fix:

```text id="3lkv95"
check Pipeline Steps Reference
install required plugin
use snippet generator
```

Jenkins maintains a Pipeline Steps Reference listing Pipeline-compatible steps from plugins. ([Jenkins][10])

---

## `input step stuck`

Cause:

```text id="9yynnt"
pipeline is waiting for human approval
```

Fix:

```text id="r9h4nb"
open build page
click input prompt
approve or abort
```

---

# 30. Interview Explanation

## What is Jenkins?

Strong answer:

```text id="ob8woj"
Jenkins is an open-source automation server commonly used for CI/CD. It can build, test, package, deploy, and automate software delivery workflows using jobs and Pipeline as Code through Jenkinsfiles.
```

## What is a Jenkins controller?

Strong answer:

```text id="g5n82s"
The Jenkins controller manages the UI, job scheduling, credentials, plugins, build history, and communication with agents. Heavy builds should run on agents, not on the controller.
```

## What is a Jenkins agent?

Strong answer:

```text id="ep6tvv"
A Jenkins agent is a worker machine that executes pipeline stages and steps. Agents can be labeled for specific capabilities such as Node.js, Docker, Terraform, or AWS.
```

## What is a Jenkinsfile?

Strong answer:

```text id="mhkm8e"
A Jenkinsfile is a pipeline-as-code file stored in source control. It defines the stages, steps, environment, parameters, credentials, and post actions for a Jenkins Pipeline.
```

## Declarative vs Scripted Pipeline?

Strong answer:

```text id="tugcyy"
Declarative Pipeline provides a structured, readable syntax recommended for most pipelines. Scripted Pipeline is more flexible and Groovy-based, useful for complex logic but easier to make hard to maintain.
```

## How do you handle secrets in Jenkins?

Strong answer:

```text id="o3d93y"
I store secrets in Jenkins Credentials and access them using `credentials()` or `withCredentials`. I never hardcode secrets in the Jenkinsfile and avoid printing them in logs.
```

## How do you do manual approval in Jenkins?

Strong answer:

```text id="w4f9pr"
I use the `input` step to pause the Pipeline and require a user to proceed or abort. For production, the approval should clearly show the immutable artifact being deployed and the rollback version.
```

---

# 31. Commit Work

Run:

```bash id="m4a5bk"
cd ~/devops-masterclass

git status
git add 08-cicd-pipelines

git commit -m "feat: add Jenkins fundamentals pipelines"
git push
```

---

# 32. Today’s Core Rules

```text id="jumybj"
Jenkins controller orchestrates.
Jenkins agents execute.
Jenkinsfile stores pipeline as code.
Use Declarative Pipeline by default.
Stages are visible phases.
Steps do the work.
Use parameters for controlled manual input.
Use credentials store for secrets.
Do not echo secrets.
Archive structured evidence.
Use input approval for production.
Approve immutable artifacts, not latest.
Run heavy builds on agents.
Keep Jenkinsfiles readable.
```

---

# Next Lesson

# Lesson 8.5 — Jenkins Production Pipeline

We will build a full Jenkins production pipeline:

```text id="fc2srs"
checkout
version computation
Node.js install/test
Docker build
GHCR/ECR login
image push
Trivy scan
SBOM generation
provenance record
Cosign signing/verification
release metadata
staging deployment
production input approval
rollback-aware deployment
archived evidence
post actions
```

[1]: https://www.jenkins.io/?utm_source=chatgpt.com "Jenkins"
[2]: https://www.jenkins.io/doc/book/pipeline/pipeline-as-code/?utm_source=chatgpt.com "Pipeline as Code - Jenkins"
[3]: https://www.jenkins.io/doc/book/pipeline/?utm_source=chatgpt.com "Pipeline"
[4]: https://www.jenkins.io/doc/book/pipeline/syntax/?utm_source=chatgpt.com "Pipeline Syntax"
[5]: https://www.jenkins.io/doc/pipeline/tour/environment/?utm_source=chatgpt.com "Using environment variables"
[6]: https://www.jenkins.io/doc/book/using/using-credentials/?utm_source=chatgpt.com "Using credentials"
[7]: https://www.jenkins.io/doc/pipeline/steps/credentials-binding/?utm_source=chatgpt.com "Credentials Binding Plugin"
[8]: https://www.jenkins.io/doc/pipeline/steps/pipeline-input-step/?utm_source=chatgpt.com "Pipeline: Input Step"
[9]: https://www.jenkins.io/doc/book/pipeline/development/?utm_source=chatgpt.com "Pipeline Development Tools"
[10]: https://www.jenkins.io/doc/pipeline/steps/?utm_source=chatgpt.com "Pipeline Steps Reference"
