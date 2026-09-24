# AWS Masterclass — Lesson 14

## Observability and Operations — CloudWatch Metrics, Logs, Alarms, Dashboards, X-Ray, Flow Logs, ALB Logs, CloudFront Logs, SLI/SLO, Incident Response, and Runbooks

Today we learn how production teams answer this question:

```text
Is my system healthy, and if not, where exactly is the problem?
```

Without observability, you are blind.

With observability, you can debug:

```text
Why is the website slow?
Why is API returning 500?
Why is ALB showing unhealthy targets?
Why did Lambda timeout?
Why did ECS task restart?
Why is RDS CPU high?
Why is CloudFront returning 403 or 502?
Who changed this resource?
What should the on-call engineer do now?
```

CloudWatch is AWS’s central monitoring service for metrics, alarms, dashboards, logs, infrastructure monitoring, application monitoring, and CloudWatch Agent data from EC2/on-premises systems. ([AWS Documentation][1])

---

# 1. Observability vs monitoring

Monitoring usually means:

```text
Watch known signals.
Alert when something crosses a threshold.
```

Observability means:

```text
Understand unknown problems by using metrics, logs, traces, events, and context.
```

Simple difference:

| Concept    | Question                           |
| ---------- | ---------------------------------- |
| Metrics    | What number changed?               |
| Logs       | What happened in detail?           |
| Traces     | Where did this request spend time? |
| Events     | What changed in the system?        |
| Dashboards | What is the current health view?   |
| Alarms     | Should someone act now?            |
| Runbooks   | What exact steps should we follow? |

Production mindset:

```text
Monitoring tells you something is wrong.
Observability helps you understand why.
Runbooks tell you what to do.
```

---

# 2. The three pillars of observability

## Metrics

Metrics are numeric time-series data.

Examples:

```text
CPUUtilization = 85%
HTTPCode_Target_5XX_Count = 25
Latency p95 = 800 ms
DatabaseConnections = 95
Lambda Errors = 12
```

CloudWatch metrics collect and track key performance data, many AWS services publish metrics automatically, and applications can publish custom metrics. ([AWS Documentation][1])

---

## Logs

Logs are event records.

Examples:

```json
{"level":"INFO","message":"Order created","orderId":"123"}
{"level":"ERROR","message":"Database connection failed"}
```

CloudWatch Logs stores logs in log groups and log streams, supports Logs Insights queries, metric filters, anomaly detection, and subscription filters for routing logs to other services. ([AWS Documentation][1])

---

## Traces

Traces show the path of a request through multiple services.

Example:

```text
User request
  ↓
CloudFront
  ↓
ALB
  ↓
ECS service
  ↓
RDS
  ↓
external payment API
```

AWS X-Ray helps analyze distributed applications with request tracing, exception collection, profiling capabilities, trace maps, segments, subsegments, and downstream dependency views. ([AWS Documentation][2]) ([AWS Documentation][3])

---

# 3. Metrics in depth

A metric has:

```text
Namespace:
  group/category of metric

Metric name:
  exact measurement

Dimension:
  key-value identifier

Timestamp:
  when it happened

Value:
  numeric value

Statistic:
  average, sum, minimum, maximum, percentile

Period:
  time bucket, such as 60 seconds or 300 seconds
```

Example:

```text
Namespace:
  AWS/EC2

MetricName:
  CPUUtilization

Dimension:
  InstanceId = i-1234567890abcdef

Statistic:
  Average

Period:
  300 seconds
```

Never say:

```text
CPU is high.
```

Say:

```text
EC2 CPUUtilization Average is 92% for 10 minutes on instance i-xxx.
```

That is production-level language.

---

# 4. Important CloudWatch namespaces

| AWS service        | Namespace                              |
| ------------------ | -------------------------------------- |
| EC2                | `AWS/EC2`                              |
| ALB / NLB          | `AWS/ApplicationELB`, `AWS/NetworkELB` |
| RDS                | `AWS/RDS`                              |
| Lambda             | `AWS/Lambda`                           |
| API Gateway        | `AWS/ApiGateway`                       |
| DynamoDB           | `AWS/DynamoDB`                         |
| ECS                | `AWS/ECS`                              |
| SQS                | `AWS/SQS`                              |
| CloudFront         | `AWS/CloudFront`                       |
| Custom app metrics | your own namespace                     |

Example custom namespace:

```text
AWSMasterclass/TodoApp
```

Good custom metrics:

```text
OrderCreatedCount
LoginFailureCount
PaymentFailureCount
TodoCreatedCount
ExternalApiLatency
```

---

# 5. Logs in depth

CloudWatch Logs has three basic levels:

```text
Log group:
  collection of logs for one app/service

Log stream:
  logs from one instance/container/function/runtime

Log event:
  one log line/event
```

Example:

```text
Log group:
  /aws/lambda/orders-api

Log stream:
  2026/07/25/[$LATEST]abcdef123

Log event:
  {"level":"ERROR","message":"DynamoDB timeout"}
```

Production rules:

```text
Use structured JSON logs.
Always include requestId/correlationId.
Set log retention.
Do not log passwords, tokens, secrets, or full credit card data.
Use consistent log levels: DEBUG, INFO, WARN, ERROR.
```

Bad log:

```text
failed
```

Good log:

```json
{
  "level": "ERROR",
  "service": "orders-api",
  "requestId": "req-123",
  "operation": "CreateOrder",
  "customerId": "cust-101",
  "error": "DynamoDBConditionalCheckFailed"
}
```

---

# 6. CloudWatch Logs Insights

Logs Insights lets you search and analyze CloudWatch Logs. AWS documents Logs Insights QL commands, sample queries, visualization, and related query languages. ([AWS Documentation][4])

Common queries:

## Find errors

```sql
fields @timestamp, @message
| filter @message like /ERROR/
| sort @timestamp desc
| limit 20
```

## Count errors by 5-minute window

```sql
fields @timestamp, @message
| filter @message like /ERROR/
| stats count(*) as errors by bin(5m)
```

## Find slow API calls in JSON logs

```sql
fields @timestamp, requestId, path, latencyMs
| filter latencyMs > 1000
| sort latencyMs desc
| limit 50
```

## Count by status code

```sql
fields @timestamp, statusCode
| stats count(*) by statusCode
```

Production tip:

```text
Do not search huge time ranges casually.
Logs Insights queries can scan large log volume.
Start narrow: last 15 minutes, one log group, one service.
```

---

# 7. Tracing in depth

Metrics say:

```text
API latency increased.
```

Logs say:

```text
Request req-123 failed during payment call.
```

Traces say:

```text
This request spent:
  20 ms in API Gateway
  80 ms in Lambda
  950 ms in DynamoDB
  3000 ms in external payment API
```

Trace vocabulary:

```text
Trace:
  full path of one request

Segment:
  work done by one service

Subsegment:
  smaller downstream call inside a service

Trace ID:
  unique identifier for one request path

Service graph:
  visual map of services and dependencies
```

X-Ray uses trace IDs to combine services that process the same request into a service graph, and segments/subsegments help show timing, errors, and downstream dependencies. ([AWS Documentation][3])

Production rule:

```text
For distributed apps, always propagate a correlation ID or trace ID.
```

---

# 8. Alarms in depth

An alarm watches a metric or log query and changes state.

Alarm states:

```text
OK:
  healthy condition

ALARM:
  threshold breached

INSUFFICIENT_DATA:
  not enough data yet
```

CloudWatch supports metric alarms, composite alarms, and log alarms; log alarms can monitor scheduled Logs Insights query results, and composite alarms can reduce alarm noise by alerting only when multiple underlying conditions are true. ([AWS Documentation][5])

Alarm parts:

```text
Metric:
  what to watch

Threshold:
  limit

Comparison:
  greater than, less than, equal, etc.

Period:
  time window

Evaluation periods:
  how many periods to evaluate

Datapoints to alarm:
  how many periods must breach

Treat missing data:
  breaching, notBreaching, ignore, missing

Action:
  SNS, Auto Scaling, OpsItem, incident, etc.
```

Example:

```text
ALB 5XX error rate >= 5%
for 5 minutes
notify on-call
```

Bad alarm:

```text
CPU > 50% for 1 minute
```

Why bad?

```text
Too noisy.
CPU spike may be normal.
No user impact.
```

Better alarm:

```text
ALB 5XX > threshold
AND target health unhealthy
AND sustained for 5 minutes
```

---

# 9. Dashboard in depth

A dashboard is not just a pretty graph.

A good dashboard is an operational cockpit.

CloudWatch dashboards can combine metrics and alarms across Regions, include operational guidance, and provide a shared view during incidents. Cross-account observability can let a monitoring account search, visualize, and analyze metrics, logs, and traces from source accounts. ([AWS Documentation][6])

Production dashboard sections:

```text
1. Customer impact
   availability, latency, 4xx, 5xx

2. Traffic
   requests, users, throughput

3. Application health
   error rate, logs, traces

4. Compute health
   CPU, memory, disk, task count

5. Data layer
   DB connections, CPU, storage, latency

6. Network/CDN
   CloudFront errors, ALB target health, VPC rejects

7. Deployment markers
   version, recent deploy time, rollback status

8. Runbook links
   what to do when this graph is red
```

---

# 10. Golden signals

Production teams often watch four golden signals:

```text
Latency:
  how long requests take

Traffic:
  how many requests/jobs/messages

Errors:
  how many requests fail

Saturation:
  how full the system is
```

Example for web API:

| Signal     | Metric                                   |
| ---------- | ---------------------------------------- |
| Latency    | p95/p99 response time                    |
| Traffic    | requests per second                      |
| Errors     | 5xx rate                                 |
| Saturation | CPU, memory, DB connections, queue depth |

Never monitor only CPU.

A service can have:

```text
CPU low
but database connections exhausted

CPU low
but API returning 500

CPU low
but users seeing 5-second latency
```

---

# 11. RED and USE methods

## RED method for request-based services

```text
Rate:
  requests per second

Errors:
  failed requests

Duration:
  latency
```

Use RED for:

```text
APIs
web services
ALB-backed apps
Lambda APIs
ECS services
```

## USE method for infrastructure

```text
Utilization:
  how busy resource is

Saturation:
  how overloaded/queued it is

Errors:
  failed operations
```

Use USE for:

```text
EC2
EBS
RDS
network
CPU
disk
memory
```

---

# 12. SLI, SLO, SLA, error budget

## SLI

SLI means:

```text
Service Level Indicator
```

It is the measurement.

Examples:

```text
availability percentage
p95 latency
successful request rate
checkout success rate
```

## SLO

SLO means:

```text
Service Level Objective
```

It is the target.

Example:

```text
99.9% of API requests should succeed over 30 days.
95% of requests should complete under 300 ms.
```

CloudWatch Application Signals can automatically collect latency and availability metrics for discovered services and operations, use them as SLIs, and track SLOs with dashboards and alarms. ([AWS Documentation][7])

## SLA

SLA means:

```text
Service Level Agreement
```

It is a promise/contract with users or customers.

## Error budget

Error budget means:

```text
Allowed unreliability.
```

Example:

```text
SLO:
  99.9% availability

Allowed downtime/error:
  0.1%
```

Production rule:

```text
SLO should drive alerting.
Do not wake people for symptoms that do not affect users.
```

---

# 13. CloudWatch Application Signals

Application Signals is AWS’s newer APM-oriented CloudWatch capability. It provides standardized dashboards for critical application metrics, correlated trace spans, application maps, and SLO tracking for business-critical operations. ([AWS Documentation][8])

Use it when you want:

```text
service map
standard latency/availability metrics
SLO dashboards
trace correlation
business-operation health
```

Example:

```text
Service:
  orders-api

Operation:
  POST /orders

SLI:
  Availability

SLO:
  99.9% successful requests over 30 days
```

---

# 14. AWS service observability checklist

## EC2

Watch:

```text
CPUUtilization
StatusCheckFailed
NetworkIn/NetworkOut
disk usage
memory usage
application logs
```

Important:

```text
EC2 memory and disk usage are not included in basic EC2 metrics by default.
Use CloudWatch Agent for memory, disk, process, and custom logs.
```

CloudWatch Agent can collect metrics such as memory, disk, process, CPU, network performance, logs, traces, and even GPU metrics from EC2 and on-premises servers. ([AWS Documentation][1])

---

## ALB

Watch:

```text
HTTPCode_ELB_5XX_Count
HTTPCode_Target_5XX_Count
TargetResponseTime
HealthyHostCount
UnHealthyHostCount
RequestCount
TargetConnectionErrorCount
```

ALB access logs capture detailed request information and store compressed log files in S3; AWS notes that access logs include requests that may not reach targets, such as malformed requests or cases where no healthy targets respond. ([AWS Documentation][9])

---

## CloudFront

Watch:

```text
Requests
BytesDownloaded
BytesUploaded
4xxErrorRate
5xxErrorRate
TotalErrorRate
CacheHitRate
OriginLatency
```

CloudFront automatically publishes operational metrics to CloudWatch, and CloudFront alarms are created in `us-east-1` because CloudFront is global and its metrics are sent to US East/N. Virginia. ([AWS Documentation][10])

CloudFront standard logs record request details and periodically save log files to a configured S3 bucket, but AWS recommends using them for request analysis rather than complete accounting because delivery is best effort. ([AWS Documentation][11])

---

## Lambda

Watch:

```text
Invocations
Errors
Duration
Throttles
ConcurrentExecutions
IteratorAge for streams
DeadLetterErrors
```

Debug with:

```text
CloudWatch Logs
X-Ray traces
Lambda Insights
DLQ/on-failure destination
```

---

## ECS/Fargate

Watch:

```text
CPUUtilization
MemoryUtilization
RunningTaskCount
DesiredTaskCount
Deployment state
ALB target health
container logs
service events
```

Important:

```text
ECS task is running does not always mean app is healthy.
ALB target health and app logs decide user-facing health.
```

---

## RDS/Aurora

Watch:

```text
CPUUtilization
DatabaseConnections
FreeStorageSpace
FreeableMemory
ReadLatency
WriteLatency
ReadIOPS
WriteIOPS
ReplicaLag
Deadlocks
```

---

## DynamoDB

Watch:

```text
ConsumedReadCapacityUnits
ConsumedWriteCapacityUnits
ThrottledRequests
SuccessfulRequestLatency
SystemErrors
UserErrors
```

---

## SQS

Watch:

```text
ApproximateNumberOfMessagesVisible
ApproximateAgeOfOldestMessage
NumberOfMessagesSent
NumberOfMessagesReceived
NumberOfMessagesDeleted
```

Golden queue rule:

```text
Queue depth tells you how much work is waiting.
Oldest message age tells you whether users/business are waiting too long.
```

---

# 15. VPC Flow Logs

VPC Flow Logs capture information about IP traffic going to and from network interfaces in your VPC, and flow logs can be sent to CloudWatch Logs, S3, or Data Firehose. AWS says flow logs can help diagnose restrictive security group rules, monitor traffic reaching instances, and understand traffic direction; they are collected outside the traffic path and do not affect network throughput or latency. ([AWS Documentation][12])

Flow log record fields include:

```text
srcaddr
dstaddr
srcport
dstport
protocol
packets
bytes
action: ACCEPT or REJECT
log-status
```

Use VPC Flow Logs for:

```text
security group debugging
NACL debugging
unexpected traffic analysis
blocked connection investigation
network audit
traffic direction validation
```

Example question:

```text
Why cannot EC2 connect to RDS on port 5432?
```

Debug path:

```text
1. Check app SG outbound.
2. Check DB SG inbound from app SG.
3. Check NACL.
4. Check route table.
5. Check VPC Flow Logs for REJECT on port 5432.
```

Cost note: publishing flow logs can generate vended log ingestion and archival charges. ([AWS Documentation][12])

---

# 16. Logs by layer

| Layer          | Logs                                                 |
| -------------- | ---------------------------------------------------- |
| User/CDN       | CloudFront access logs                               |
| Web firewall   | WAF logs                                             |
| Load balancer  | ALB access logs                                      |
| Network        | VPC Flow Logs                                        |
| Compute        | EC2 system/app logs, ECS container logs, Lambda logs |
| Database       | RDS logs, slow query logs, audit logs                |
| API            | API Gateway access/execution logs                    |
| Security/audit | CloudTrail                                           |
| Config changes | AWS Config                                           |

Production rule:

```text
Metrics tell you where to look.
Logs tell you what happened.
Traces tell you where time went.
CloudTrail tells you who changed things.
```

---

# 17. Incident response

An incident is:

```text
A user-impacting or risk-impacting event that needs coordinated response.
```

Examples:

```text
API 5xx spike
database unavailable
CloudFront 502
deployment broke login
queue backlog growing
security group opened publicly
suspected credential leak
```

AWS Systems Manager Incident Manager integrates with services such as CloudWatch, CloudTrail, Systems Manager, and EventBridge. Response plans can define responders, automated response, communication tools, escalations, runbooks, and post-incident analysis. ([AWS Documentation][13])

Incident lifecycle:

```text
1. Detect
2. Triage
3. Mitigate
4. Resolve
5. Review
6. Prevent recurrence
```

---

# 18. Runbook

A runbook is a repeatable procedure for handling an operational problem.

Bad runbook:

```text
Check AWS.
Fix issue.
```

Good runbook:

```text
Alarm:
  ALBTarget5XXHigh

Impact:
  users may receive 5xx responses

First 5 minutes:
  check ALB target health
  check recent deployments
  check ECS service events
  check app logs
  check database health

Rollback:
  redeploy previous task definition

Escalation:
  contact backend owner if DB errors continue
```

Incident Manager supports Automation runbooks and response plans so responders can follow predefined steps or automate remediation during incidents. ([AWS Documentation][13])

---

# 19. Practical troubleshooting flows

## Flow 1 — Website is down

```text
1. DNS resolves?
2. CloudFront status?
3. CloudFront 4xx/5xx metrics?
4. CloudFront behavior routes to correct origin?
5. ALB reachable?
6. ALB listener exists?
7. Target group has healthy targets?
8. EC2/ECS/Lambda logs show errors?
9. Database reachable?
10. Recent deployment or config change?
11. CloudTrail shows changes?
```

---

## Flow 2 — ALB returns 503

Meaning:

```text
Usually no healthy targets.
```

Check:

```bash
aws elbv2 describe-target-health \
  --target-group-arn "$TG_ARN" \
  --query 'TargetHealthDescriptions[].{Target:Target.Id,State:TargetHealth.State,Reason:TargetHealth.Reason,Description:TargetHealth.Description}' \
  --output table
```

Then check:

```text
EC2/ECS security group
health check path
app port
container listening address
user data/container logs
target group target type
subnet/AZ registration
```

---

## Flow 3 — CloudFront 502

Check:

```text
origin DNS name
origin protocol policy
ALB listener protocol
TLS certificate mismatch
ALB target health
security groups
origin timeout
```

---

## Flow 4 — Lambda API slow

Check:

```text
Lambda Duration
Lambda Errors
Lambda Throttles
API Gateway latency
DynamoDB latency
cold starts
external API latency
X-Ray trace segments
```

---

## Flow 5 — RDS slow

Check:

```text
CPUUtilization
DatabaseConnections
FreeableMemory
ReadLatency / WriteLatency
IOPS
slow query logs
connection pooling
recent deployment
query plan/index changes
```

---

# 20. Hands-On Lab 14A — CloudWatch Logs, Logs Insights, Metric Filter, Alarm, and Dashboard

This lab creates small CloudWatch resources.

Cost warning:

```text
CloudWatch Logs ingestion, custom metrics, alarms, and dashboards can generate charges.
Use tiny test logs and clean up immediately.
```

Region:

```text
ap-south-1
```

---

## Step 1 — Set variables

```bash
export AWS_REGION=ap-south-1
export AWS_DEFAULT_REGION=ap-south-1

TS="$(date +%Y%m%d%H%M%S)"
LOG_GROUP="/aws-masterclass/observability-demo-${TS}"
LOG_STREAM="app-${TS}"
METRIC_NAMESPACE="AWSMasterclass/Observability"
METRIC_NAME="AppErrorCount"
FILTER_NAME="error-count-filter"
ALARM_NAME="aws-masterclass-app-error-alarm-${TS}"
DASHBOARD_NAME="aws-masterclass-observability-${TS}"

echo "$LOG_GROUP"
```

---

## Step 2 — Create log group and stream

```bash
aws logs create-log-group \
  --log-group-name "$LOG_GROUP"

aws logs put-retention-policy \
  --log-group-name "$LOG_GROUP" \
  --retention-in-days 1

aws logs create-log-stream \
  --log-group-name "$LOG_GROUP" \
  --log-stream-name "$LOG_STREAM"
```

---

## Step 3 — Put structured logs

```bash
NOW_MS="$(($(date +%s) * 1000))"

aws logs put-log-events \
  --log-group-name "$LOG_GROUP" \
  --log-stream-name "$LOG_STREAM" \
  --log-events \
    timestamp=$NOW_MS,message='{"level":"INFO","service":"orders-api","requestId":"req-1","path":"/health","statusCode":200,"latencyMs":25}' \
    timestamp=$((NOW_MS+1000)),message='{"level":"INFO","service":"orders-api","requestId":"req-2","path":"/orders","statusCode":201,"latencyMs":80}' \
    timestamp=$((NOW_MS+2000)),message='{"level":"ERROR","service":"orders-api","requestId":"req-3","path":"/orders","statusCode":500,"latencyMs":1200,"error":"DynamoDBTimeout"}'
```

---

## Step 4 — Query logs with Logs Insights

```bash
START_TIME="$(date -d '15 minutes ago' +%s)"
END_TIME="$(date +%s)"

QUERY_ID="$(aws logs start-query \
  --log-group-name "$LOG_GROUP" \
  --start-time "$START_TIME" \
  --end-time "$END_TIME" \
  --query-string 'fields @timestamp, @message | filter @message like /ERROR/ | sort @timestamp desc | limit 20' \
  --query 'queryId' \
  --output text)"

echo "$QUERY_ID"

sleep 5

aws logs get-query-results \
  --query-id "$QUERY_ID"
```

Expected:

```text
You should see the ERROR log event.
```

---

## Step 5 — Create metric filter from logs

This converts matching log events into a CloudWatch metric.

```bash
aws logs put-metric-filter \
  --log-group-name "$LOG_GROUP" \
  --filter-name "$FILTER_NAME" \
  --filter-pattern '{ $.level = "ERROR" }' \
  --metric-transformations \
      metricName="$METRIC_NAME",metricNamespace="$METRIC_NAMESPACE",metricValue=1,defaultValue=0
```

Verify:

```bash
aws logs describe-metric-filters \
  --log-group-name "$LOG_GROUP" \
  --query 'metricFilters[].{Name:filterName,Pattern:filterPattern,Transformations:metricTransformations}' \
  --output table
```

---

## Step 6 — Send another ERROR log to trigger metric

```bash
NOW_MS="$(($(date +%s) * 1000))"

aws logs put-log-events \
  --log-group-name "$LOG_GROUP" \
  --log-stream-name "$LOG_STREAM" \
  --log-events \
    timestamp=$NOW_MS,message='{"level":"ERROR","service":"orders-api","requestId":"req-4","path":"/orders","statusCode":500,"latencyMs":1500,"error":"DatabaseConnectionFailed"}'
```

Wait 2–3 minutes for metric ingestion.

Check metric:

```bash
aws cloudwatch get-metric-statistics \
  --namespace "$METRIC_NAMESPACE" \
  --metric-name "$METRIC_NAME" \
  --start-time "$(date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%SZ)" \
  --end-time "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --period 60 \
  --statistics Sum \
  --output table
```

---

## Step 7 — Create alarm without notification action

```bash
aws cloudwatch put-metric-alarm \
  --alarm-name "$ALARM_NAME" \
  --alarm-description "AWS Masterclass demo alarm when app error count is >= 1" \
  --namespace "$METRIC_NAMESPACE" \
  --metric-name "$METRIC_NAME" \
  --statistic Sum \
  --period 60 \
  --evaluation-periods 1 \
  --datapoints-to-alarm 1 \
  --threshold 1 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --treat-missing-data notBreaching \
  --tags Key=Project,Value=aws-masterclass Key=Environment,Value=dev
```

Check alarm:

```bash
aws cloudwatch describe-alarms \
  --alarm-names "$ALARM_NAME" \
  --query 'MetricAlarms[].{Name:AlarmName,State:StateValue,Reason:StateReason}' \
  --output table
```

---

## Step 8 — Create a simple dashboard

```bash
cat > /tmp/aws-masterclass-dashboard.json <<EOF
{
  "widgets": [
    {
      "type": "text",
      "x": 0,
      "y": 0,
      "width": 24,
      "height": 3,
      "properties": {
        "markdown": "# AWS Masterclass Observability Demo\\nWatch app error count and follow the runbook when alarm enters ALARM."
      }
    },
    {
      "type": "metric",
      "x": 0,
      "y": 3,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          [ "$METRIC_NAMESPACE", "$METRIC_NAME" ]
        ],
        "period": 60,
        "stat": "Sum",
        "region": "$AWS_REGION",
        "title": "Application Error Count"
      }
    },
    {
      "type": "alarm",
      "x": 12,
      "y": 3,
      "width": 12,
      "height": 6,
      "properties": {
        "alarms": [
          "arn:aws:cloudwatch:${AWS_REGION}:$(aws sts get-caller-identity --query Account --output text):alarm:${ALARM_NAME}"
        ],
        "title": "Error Alarm"
      }
    }
  ]
}
EOF

aws cloudwatch put-dashboard \
  --dashboard-name "$DASHBOARD_NAME" \
  --dashboard-body file:///tmp/aws-masterclass-dashboard.json
```

Verify:

```bash
aws cloudwatch get-dashboard \
  --dashboard-name "$DASHBOARD_NAME" \
  --query 'DashboardName'
```

---

# 21. Cleanup Lab 14A

Delete alarm:

```bash
aws cloudwatch delete-alarms \
  --alarm-names "$ALARM_NAME"
```

Delete dashboard:

```bash
aws cloudwatch delete-dashboards \
  --dashboard-names "$DASHBOARD_NAME"
```

Delete metric filter:

```bash
aws logs delete-metric-filter \
  --log-group-name "$LOG_GROUP" \
  --filter-name "$FILTER_NAME"
```

Delete log group:

```bash
aws logs delete-log-group \
  --log-group-name "$LOG_GROUP"
```

Verify:

```bash
aws logs describe-log-groups \
  --log-group-name-prefix "$LOG_GROUP"

aws cloudwatch describe-alarms \
  --alarm-names "$ALARM_NAME"
```

---

# 22. Optional Lab 14B — Create a local incident runbook

```bash
mkdir -p ~/aws-masterclass/observability/runbooks

cat > ~/aws-masterclass/observability/runbooks/alb-5xx-runbook.md <<'EOF'
# Runbook: ALB 5XX Spike

## Alarm

ALBTarget5XXHigh

## Impact

Users may receive HTTP 5xx errors.

## First checks

1. Check ALB target group health.
2. Check recent deployments.
3. Check ECS/EC2 application logs.
4. Check database metrics.
5. Check CloudFront 5xx and origin errors.
6. Check CloudTrail for recent config changes.

## AWS CLI commands

Target health:

aws elbv2 describe-target-health \
  --target-group-arn "$TG_ARN" \
  --query 'TargetHealthDescriptions[].{Target:Target.Id,State:TargetHealth.State,Reason:TargetHealth.Reason,Description:TargetHealth.Description}' \
  --output table

Recent CloudTrail events:

aws cloudtrail lookup-events \
  --max-results 10 \
  --query 'Events[].{Time:EventTime,Name:EventName,User:Username,Source:EventSource}' \
  --output table

## Mitigation

- Roll back latest deployment if issue started after deploy.
- Scale out app service if saturation is high.
- Restart unhealthy tasks only after logs are captured.
- Escalate to database owner if DB latency/connections are high.

## Resolution criteria

- ALB 5xx returns to normal.
- Target group healthy.
- Error logs stop increasing.
- User-facing health checks pass.

## Post-incident

- Write timeline.
- Identify root cause.
- Add missing alarm/log/trace.
- Add preventive CI/CD or IaC guardrail.
EOF
```

---

# 23. Common observability mistakes

## Mistake 1 — No log retention

Problem:

```text
Logs stay forever and cost grows.
```

Fix:

```text
Set retention per log group.
Example:
  dev: 1–7 days
  staging: 7–30 days
  prod: 30–365+ days depending compliance
```

---

## Mistake 2 — Monitoring only CPU

Problem:

```text
CPU can be normal while users are failing.
```

Fix:

```text
Monitor user-facing signals:
  latency
  5xx
  availability
  request count
  target health
```

---

## Mistake 3 — Too many noisy alarms

Problem:

```text
On-call ignores alerts.
```

Fix:

```text
Alert only on actionable symptoms.
Use composite alarms.
Use SLO-based alerting.
Tune evaluation periods.
```

---

## Mistake 4 — Logs without request ID

Problem:

```text
Cannot follow one request across services.
```

Fix:

```text
Generate requestId at edge/API.
Pass it through every service.
Log it everywhere.
```

---

## Mistake 5 — No dashboard during incident

Problem:

```text
Everyone asks different questions and wastes time.
```

Fix:

```text
Create dashboards organized by service health, customer impact, dependencies, and runbooks.
```

---

## Mistake 6 — No post-incident review

Problem:

```text
Same incident repeats.
```

Fix:

```text
Write blameless postmortem.
Add preventive control.
Update runbook.
Improve alarm/dashboard/logging.
```

---

# 24. Production observability baseline

For a real production app, configure:

```text
CloudWatch:
  metrics, alarms, dashboards, logs

Application logs:
  structured JSON with requestId

Tracing:
  X-Ray or OpenTelemetry

ALB:
  metrics and access logs

CloudFront:
  metrics, access logs, 4xx/5xx alarms

VPC:
  Flow Logs for important VPCs/subnets/ENIs

Database:
  metrics, slow query logs, alarms

Security:
  CloudTrail, GuardDuty, Config, Inspector

Incidents:
  response plan, runbooks, escalation, postmortem

SLOs:
  availability and latency goals tied to business impact
```

---

# 25. Minimum alarms for a production web app

| Layer      | Alarm                                   |
| ---------- | --------------------------------------- |
| CloudFront | high 5xx error rate                     |
| CloudFront | high 4xx if unexpected                  |
| ALB        | target 5xx high                         |
| ALB        | unhealthy targets > 0                   |
| ECS/EC2    | CPU/memory saturation                   |
| ECS        | running tasks below desired             |
| Lambda     | errors/throttles/duration high          |
| RDS        | CPU high, storage low, connections high |
| SQS        | oldest message age high                 |
| DynamoDB   | throttled requests                      |
| Billing    | estimated charges/budget alert          |
| Security   | GuardDuty high-severity finding         |

---

# 26. Certification angle

## CLF-C02

Know:

```text
CloudWatch monitors metrics, logs, alarms, and dashboards.
CloudTrail audits API activity.
X-Ray traces application requests.
VPC Flow Logs capture network traffic metadata.
CloudWatch alarms can notify or trigger actions.
```

## SAA-C03

Know deeply:

```text
metrics vs logs vs traces
CloudWatch namespaces/dimensions/statistics
ALB and CloudFront metrics/logs
VPC Flow Logs for network troubleshooting
CloudWatch Agent for EC2 memory/disk/logs
SLO/SLI basics
dashboard design
alarm tuning
observability for multi-tier apps
```

## DOP-C02

Know operationally:

```text
CloudWatch Logs Insights
metric filters
composite alarms
deployment-aware dashboards
X-Ray trace debugging
incident response runbooks
CloudTrail investigation
SLO/error budget alerting
automation from alarms
post-incident improvement
```

---

# 27. Interview answer

Memorize this:

```text
In production AWS systems, I use observability to understand service health and troubleshoot incidents quickly. Metrics tell me what changed numerically, logs tell me what happened in detail, traces show the path and latency of individual requests, and events or audit logs show what changed in the environment.

I use CloudWatch metrics, logs, alarms, and dashboards as the core monitoring layer. For EC2, I add CloudWatch Agent when I need memory, disk, process, and custom log collection. For ALB, I monitor request count, target response time, target 5xx, ELB 5xx, and healthy/unhealthy host count. For CloudFront, I monitor request volume, cache behavior, 4xx/5xx error rate, and origin latency. For networking issues, I use VPC Flow Logs to inspect ACCEPT and REJECT traffic patterns. For distributed applications, I use X-Ray or OpenTelemetry tracing to identify where a request is slow or failing.

I design alarms around user impact, not just infrastructure noise. Good alarms watch availability, latency, 5xx, unhealthy targets, queue age, throttling, and database saturation. I use dashboards as operational cockpits and attach runbook guidance so responders know what to check first. For mature systems, I define SLIs such as availability and p95 latency, set SLOs around business goals, and use error budgets to decide when reliability work should take priority over feature releases.
```

---

# 28. Quick quiz

```text
1. What is the difference between monitoring and observability?
2. What are the three main observability pillars?
3. What is a metric?
4. What is a log group?
5. What is a log stream?
6. What is a trace?
7. What is X-Ray used for?
8. What are CloudWatch alarm states?
9. What is a composite alarm?
10. What is Logs Insights?
11. What is VPC Flow Logs used for?
12. What does ACCEPT/REJECT mean in flow logs?
13. What are ALB access logs used for?
14. What are CloudFront logs used for?
15. What is an SLI?
16. What is an SLO?
17. What is an error budget?
18. What are the four golden signals?
19. What should a runbook contain?
20. Why should alerts be tied to user impact?
```

Answers:

```text
1. Monitoring watches known signals; observability helps debug unknown problems.
2. Metrics, logs, and traces.
3. Numeric time-series measurement.
4. Collection of logs for an app/service.
5. Log sequence from one source such as function/container/instance.
6. Full request path through services.
7. Distributed request tracing and service maps.
8. OK, ALARM, INSUFFICIENT_DATA.
9. Alarm based on multiple underlying alarms to reduce noise.
10. CloudWatch log query and analysis tool.
11. Capturing IP traffic metadata for VPC network debugging/security.
12. Whether traffic was allowed or rejected by network controls.
13. Detailed request analysis for load balancer traffic.
14. CDN request/error/cache/origin analysis.
15. Service Level Indicator, a reliability measurement.
16. Service Level Objective, a target for an SLI.
17. Amount of unreliability allowed by the SLO.
18. Latency, traffic, errors, saturation.
19. Alarm meaning, impact, commands, first checks, mitigation, escalation, resolution criteria.
20. To avoid noisy alerts and wake people only for actionable problems.
```

# Next Lesson

```text
AWS Lesson 15 — Hybrid Cloud and Migration:
Site-to-Site VPN, Direct Connect, Transit Gateway, Route 53 Resolver, Storage Gateway, DataSync, DMS, Application Migration Service, Snow Family, hybrid DNS, CIDR planning, and migration strategies
```

[1]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/WhatIsCloudWatch.html "What is Amazon CloudWatch? - Amazon CloudWatch"
[2]: https://docs.aws.amazon.com/xray/ "docs.aws.amazon.com"
[3]: https://docs.aws.amazon.com/xray/latest/devguide/xray-concepts.html "AWS X-Ray concepts - AWS X-Ray"
[4]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/CWL_AnalyzeLogData_LogsInsights.html "CloudWatch Logs Insights query language (Logs Insights QL) - Amazon CloudWatch Logs"
[5]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch_Alarms.html "Using Amazon CloudWatch alarms - Amazon CloudWatch"
[6]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch_Dashboards.html "Using Amazon CloudWatch dashboards - Amazon CloudWatch"
[7]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-ServiceLevelObjectives.html "Service level objectives (SLOs) - Amazon CloudWatch"
[8]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-Application-Monitoring-Intro.html "Application performance monitoring (APM) - Amazon CloudWatch"
[9]: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-access-logs.html "Access logs for your Application Load Balancer - Elastic Load Balancing"
[10]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/monitoring-using-cloudwatch.html "Monitor CloudFront metrics with Amazon CloudWatch - Amazon CloudFront"
[11]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/AccessLogs.html "Access logs (standard logs) - Amazon CloudFront"
[12]: https://docs.aws.amazon.com/vpc/latest/userguide/flow-logs.html "Logging IP traffic using VPC Flow Logs - Amazon Virtual Private Cloud"
[13]: https://docs.aws.amazon.com/incident-manager/latest/userguide/what-is-incident-manager.html "What Is AWS Systems Manager Incident Manager? - Incident Manager"
