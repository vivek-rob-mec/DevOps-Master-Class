AWS Masterclass — Phase 3
Lesson 61: AWS Cost Architecture and FinOps
1. Lesson objectives

By the end of this lesson, you will understand how to:

Distinguish cost reduction from cost optimization.
Build a production AWS cost-management architecture.
Understand AWS billing dimensions and line items.
Use Cost Explorer for analysis and forecasting.
Export detailed billing data with AWS Data Exports and CUR 2.0.
Query cost data using S3 and Athena.
Design cost-allocation tags and Cost Categories.
Implement showback and chargeback.
Use AWS Budgets and budget actions safely.
Detect unexpected spending using Cost Anomaly Detection.
Understand On-Demand, Spot, Savings Plans and Reserved Instances.
Select among the four current Savings Plans types.
Measure Savings Plans coverage and utilization.
Avoid overcommitting to discounts.
Use Cost Optimization Hub, Compute Optimizer and Trusted Advisor.
Rightsize EC2, EBS, RDS, Aurora, Lambda and ECS workloads.
Optimize S3, CloudFront, NAT Gateway and data-transfer costs.
Design cost-efficient Kubernetes and container platforms.
Measure application unit economics.
Establish a FinOps operating model.
Automate cost governance with Terraform.
Build a practical cost dashboard and alerting lab.
2. Cost optimization is not simply “spend less”

Bad cost management:

Reduce ECS task count
Stop Multi-AZ database
Remove backup copies
Disable application logs
Buy the longest possible commitment

This may reduce the bill while increasing:

Outages.
Recovery time.
Security risk.
Engineering work.
Customer dissatisfaction.
Commitment waste.

Correct cost optimization means:

Deliver the required business outcome
at the lowest sustainable cost
while meeting:
- Security
- Reliability
- Performance
- Compliance
- Recovery requirements
3. FinOps mental model

FinOps combines:

Engineering
Finance
Product
Procurement
Business leadership

The goal is shared responsibility for cloud value.

Finance:
How much are we spending?

Engineering:
Which resources create the spending?

Product:
Which customer or capability receives value?

Leadership:
Should we continue, optimize or stop this investment?
4. The FinOps lifecycle

A practical lifecycle is:

Inform
   |
   v
Optimize
   |
   v
Operate
   |
   └───────────────> Repeat
Inform
Allocate costs.
Build dashboards.
Measure trends.
Forecast.
Identify owners.
Calculate unit cost.
Optimize
Delete waste.
Right-size resources.
Improve architectures.
Purchase appropriate commitments.
Use Spot.
Move data to suitable storage classes.
Operate
Make cost part of daily engineering.
Review anomalies.
Enforce budgets.
Track optimization work.
Measure realized—not only estimated—savings.
5. Cost architecture overview
AWS accounts and resources
        |
        v
Billing and usage records
        |
        ├── Cost Explorer
        ├── AWS Budgets
        ├── Cost Anomaly Detection
        ├── Cost Optimization Hub
        └── AWS Data Exports
                  |
                  v
              Amazon S3
                  |
                  v
               Athena
                  |
          ┌───────┼────────┐
          v       v        v
      QuickSight  BI     FinOps pipeline

AWS Billing and Cost Management provides cost analysis, organization, budgeting and optimization capabilities. Cost allocation tags and Cost Categories can be used across tools such as Cost Explorer and Data Exports.

Part 1 — Understanding the AWS bill
6. Major billing dimensions

AWS costs can usually be examined by:

AWS account
Service
Region
Availability Zone
Usage type
API operation
Purchase option
Instance type
Resource
Cost allocation tag
Cost Category
Charge type
Billing entity

Cost Explorer supports filtering and grouping across dimensions such as service, linked account, Region, Availability Zone, usage type, instance type and operation.

7. Account as the first allocation boundary

Example organization:

Management account
Security account
Network account
TodoApp Production account
TodoApp Development account
Data Platform account

Account-level costs are often easier to govern than costs from several unrelated workloads mixed inside one account.

Use accounts for:

Environment separation.
Business-unit ownership.
Product ownership.
Security boundaries.
Cost responsibility.
Budget ownership.

Use resource tags for finer allocation inside each account.

8. Common charge types

Cost analysis may include:

Usage charges
Upfront commitment charges
Recurring commitment charges
Credits
Refunds
Taxes
Support fees
Savings Plans negation entries
Savings Plans covered usage
Reserved Instance fees
Data transfer

Do not assume the simple total of all usage line items equals the invoice without understanding credits, refunds, commitments and other charge types.

9. Unblended cost

Unblended cost is the direct cost associated with individual usage or fee line items before some organization-level allocation effects.

It is useful when asking:

What did this account or resource directly consume?
10. Amortized cost

Amortized cost spreads upfront and recurring commitment charges across the period in which the commitment provides value.

Example:

Three-year commitment paid upfront

Cash view:

Large payment in month 1
Little payment in following months

Amortized view:

Commitment cost distributed across its useful term

Use amortized cost for:

Monthly product economics.
Commitment-aware team reporting.
Comparing On-Demand and committed usage.
Long-term budgeting.
11. Net amortized cost

Net amortized cost also incorporates applicable credits, discounts and refunds.

This can be useful for understanding the effective cost after commercial adjustments.

However, finance, product and engineering may need different views:

Engineering:
Amortized operational cost

Finance:
Invoice and cash cost

Business unit:
Allocated chargeback cost

Define which metric your dashboards use.

12. Blended cost

Blended rates can average eligible usage pricing across accounts in an organization.

They may be useful for certain consolidated billing analyses, but they can hide the exact economic impact of a specific account or commitment.

For most product and workload optimization:

Use amortized or net amortized cost

unless your organization has a deliberate blended-rate model.

13. Cost versus usage

A cost increase can occur because:

Usage increased
Price changed
Discount expired
Commitment coverage fell
Region changed
Instance family changed
Data transfer increased
Credit expired

Always analyze cost and usage together.

Example:

RDS cost increased 40%

Possible explanations:

Database grew 40%
or
Same usage lost RI/Savings Plan coverage
or
Instance was moved to a more expensive class
Part 2 — AWS Cost Explorer
14. What is Cost Explorer?

AWS Cost Explorer provides interactive cost and usage analysis through graphs, reports, filters and APIs.

When initially enabled, it prepares the current month and previous 13 months of cost data. Current documentation describes up to 13 months of historical analysis plus the current month and longer forecast capabilities through the console; API forecast ranges vary by granularity.

15. Cost Explorer workflow
1. Select time range.

2. Choose cost metric.

3. Choose granularity.

4. Filter.

5. Group.

6. Compare periods.

7. Save report.

8. Investigate top drivers.

Example:

Time:
Last 30 days

Metric:
Amortized cost

Filter:
Account = TodoApp Production

Group:
Service
16. Useful Cost Explorer reports

Create saved reports for:

Monthly organization cost
Cost by AWS account
Cost by service
Cost by application tag
Cost by environment
Daily production cost
Data-transfer cost
EC2 cost by instance type
RDS cost by database engine
Savings Plans coverage
Savings Plans utilization
Reserved Instance utilization
17. Daily versus monthly granularity
Daily

Useful for:

Deployment cost changes.
Anomalies.
Traffic spikes.
Short experiments.
Unexpected service activation.
Monthly

Useful for:

Long-term trends.
Forecasting.
Executive reporting.
Year-over-year comparisons.
Commitment planning.
18. Hourly granularity

Hourly cost data helps investigate:

Short-lived EC2 fleets.
Build workloads.
Batch processing.
Traffic bursts.
Experiments.
Cryptomining incidents.

Cost Explorer can provide optional hourly data for recent periods. AWS charges for storing/querying optional granular usage records, so enable it only where the operational benefit justifies the cost.

19. Multi-year Cost Explorer data

Standard Cost Explorer data is suitable for recent analysis. Multi-year monthly data can be enabled when you need:

Year-over-year comparison.
Seasonal analysis.
Long-term growth.
Commitment planning.
Budget baselines.

AWS specifically recommends multi-year data when evaluating long-term trends beyond the default historical window.

20. Cost Explorer forecasting

Cost Explorer can forecast likely future costs using historical usage patterns.

Use forecasts for:

Month-end projections.
Quarterly planning.
Budget thresholds.
Hiring or launch planning.
Commitment evaluation.

A forecast is not guaranteed. AWS may not provide a forecast where insufficient historical data exists.

21. Cost Explorer API

The Cost Explorer API lets you automate queries such as:

Daily production cost
Month-to-date total
Cost by linked account
Cost by service
Cost by tag
Forecast
Commitment coverage

The API supports aggregated and granular cost and usage queries.

Example CLI:

aws ce get-cost-and-usage \
  --time-period \
    Start=2026-08-01,End=2026-08-04 \
  --granularity DAILY \
  --metrics AmortizedCost \
  --group-by \
    Type=DIMENSION,Key=SERVICE
22. Cost Explorer limitations

Cost Explorer is excellent for interactive analysis, but it is not the best choice when you need:

Every billing line item.
Custom SQL at scale.
Complex internal allocation.
Multi-year detailed data.
Integration with external BI.
Resource-level unit economics.
Custom chargeback logic.

For those requirements, use AWS Data Exports.

Part 3 — AWS Data Exports and CUR 2.0
23. What is AWS Data Exports?

AWS Data Exports delivers billing and cost-management datasets to S3 and allows custom column selection and SQL-style filtering.

As of August 2026, AWS describes Cost and Usage Report 2.0—CUR 2.0—as the recommended detailed cost and usage export format. Data Exports also supports FOCUS-format exports and other billing datasets.

24. CUR 2.0 improvements

Compared with the legacy CUR, CUR 2.0 provides:

A more consistent schema.
Nested key-value columns to reduce sparse columns.
SQL-based data selection.
Integration with S3 analytics.
Better export control.

Legacy CUR columns could change depending on monthly usage, tags and Cost Categories. CUR 2.0 provides a more predictable schema.

25. Data export architecture
AWS Billing
    |
    v
CUR 2.0 Data Export
    |
    v
S3 cost-data bucket
    |
    ├── Athena
    ├── Redshift
    ├── QuickSight
    ├── Glue/ETL
    └── External FinOps platform

Athena can query CUR data stored in S3 using SQL without managing a database server.

26. Data-export delivery timing

After creating a new export, initial delivery may take time. AWS documentation states that report delivery can take up to 24 hours to begin.

Do not create a report and immediately assume the configuration failed because the S3 prefix is still empty.

27. Cost-data S3 bucket

Recommended controls:

Dedicated billing-data account
S3 Block Public Access
SSE-KMS encryption
Versioning
Lifecycle policy
Restricted reader roles
Athena query-result encryption
CloudTrail data-event logging where required

Billing data can reveal:

Account names.
Workload architecture.
Product usage.
Discounts.
Commercial terms.
Resource identifiers.
Business activity.

Treat it as sensitive financial information.

28. CUR 2.0 query examples
Cost by account
SELECT
    line_item_usage_account_id,
    SUM(line_item_unblended_cost) AS cost
FROM cur2
WHERE billing_period_start_date =
      DATE '2026-08-01'
GROUP BY line_item_usage_account_id
ORDER BY cost DESC;
Cost by service
SELECT
    product_product_name,
    SUM(line_item_unblended_cost) AS cost
FROM cur2
WHERE billing_period_start_date =
      DATE '2026-08-01'
GROUP BY product_product_name
ORDER BY cost DESC;

Exact table and column names depend on the export schema and selected columns.

29. Find NAT Gateway costs
SELECT
    line_item_usage_type,
    SUM(line_item_usage_amount) AS usage,
    SUM(line_item_unblended_cost) AS cost
FROM cur2
WHERE product_product_name =
      'Amazon Elastic Compute Cloud'
  AND line_item_usage_type LIKE '%NatGateway%'
GROUP BY line_item_usage_type
ORDER BY cost DESC;

Use this to separate:

NAT Gateway hourly cost
NAT Gateway data-processing cost
Related inter-AZ or internet data transfer
30. Cost by application tag

Conceptual query:

SELECT
    resource_tags['Application'] AS application,
    SUM(line_item_unblended_cost) AS cost
FROM cur2
GROUP BY resource_tags['Application']
ORDER BY cost DESC;

CUR 2.0 uses nested structures for some tag and product attributes, which reduces the schema changes and sparsity common in legacy CUR.

31. FOCUS exports

FOCUS is a standardized cloud cost and usage schema intended to simplify multi-cloud FinOps analysis.

Use FOCUS when:

Comparing AWS with other cloud providers.
Feeding a multi-cloud data platform.
Standardizing internal cost terminology.
Building reusable FinOps reports.

Use CUR 2.0 when you need maximum AWS-specific detail.

32. QuickSight cost dashboard

Possible dashboard pages:

Executive summary
Account spend
Service trends
Application spend
Environment spend
Commitment coverage
Commitment utilization
Anomalies
Optimization opportunities
Unit economics

AWS Data Exports can integrate with QuickSight and can deploy prebuilt cost and usage visualization capabilities.

Part 4 — Cost allocation
33. Cost allocation hierarchy

A practical hierarchy is:

AWS account
    |
    v
Cost Category
    |
    v
Resource tags
    |
    v
Resource-level usage

Example:

Account:
yds-prod-todoapp

Cost Category:
Customer Products

Tags:
Application = TodoApp
Environment = production
Team = Platform

Resource:
ECS service todo-api
34. Cost-allocation tags

A resource tag becomes available for billing analysis only after it is activated as a cost-allocation tag in Billing and Cost Management.

Activated tags can then appear in Cost Explorer and detailed cost reports.

Recommended tags:

Application
Environment
Owner
Team
CostCenter
BusinessUnit
Product
Customer
Project
ManagedBy
DataClassification
35. Tag naming standard

Good:

Application = TodoApp
Environment = production
CostCenter = CC-1004
Owner = platform-team

Bad:

environment = prod
Environment = Production
env = LIVE
ENV = production

Tags are case sensitive.

Inconsistent keys and values fragment cost reporting.

36. Tagging limitations

Tags do not solve every allocation problem because:

Some resources are not taggable.
Some costs are shared.
Some historical costs predate tag activation.
Data transfer may not map cleanly to one resource.
Commitments may apply across accounts.
Support and tax charges may be centralized.
Tag changes may not retroactively reclassify previous charges.

Use Cost Categories and allocation rules for shared or untagged costs.

37. Account tags

AWS supports using account-level tags as cost allocation dimensions.

Once activated, account tags can work with Cost Explorer, CUR 2.0, FOCUS, Budgets, Cost Categories and Cost Anomaly Detection.

Example:

Account:
123456789012

Account tags:
BusinessUnit = Product
Environment = production
Owner = Platform

This is useful when every resource in an account belongs to the same business boundary.

38. Cost Categories

Cost Categories provide business-oriented cost groupings based on rules.

Example:

Cost Category:
Business Service

Rules:

If account = TodoApp Production
    → TodoApp

If tag Application = DataPlatform
    → Data Platform

If service = AWS Support
    → Shared Platform Cost

Cost Categories can be used in Cost Explorer and Data Exports and can define split-charge rules for shared costs.

39. Split-charge rules

Suppose the Network account costs:

₹100,000 per month

Allocation by application traffic:

TodoApp:
50%

Data Platform:
30%

Internal Tools:
20%

Allocated network cost:

TodoApp:
₹50,000

Data Platform:
₹30,000

Internal Tools:
₹20,000

Shared-cost allocation should have a documented business driver:

Usage.
Headcount.
Revenue.
Request volume.
Storage.
Equal split.
Direct ownership.
40. Showback versus chargeback
Showback

Teams see the cost attributed to them, but no financial transfer occurs.

Platform team used ₹500,000 of AWS services.
Chargeback

The cost is financially allocated or recovered from the team or business unit.

Platform team budget is charged ₹500,000.

Showback improves awareness; chargeback drives direct financial accountability.

41. Billing views

Billing views provide filtered access to cost-management data.

They can allow teams or departments to view only the cost data relevant to them without granting broad access to the management account’s complete billing dataset.

Example:

TodoApp billing view:
Accounts = TodoApp production and nonproduction
Cost Category = TodoApp
Part 5 — AWS Budgets
42. What is AWS Budgets?

AWS Budgets monitors cost, usage and commitment-related thresholds.

Possible budget types include:

Cost budget
Usage budget
Savings Plans budget
Reserved Instance budget

A budget can notify when actual or forecasted values cross configured thresholds.

43. Budget hierarchy

Recommended:

Organization budget
    |
    ├── Account budget
    |
    ├── Product budget
    |
    ├── Environment budget
    |
    └── Service-specific budget

Example:

TodoApp monthly:
₹300,000

Production:
₹240,000

Nonproduction:
₹60,000

CloudWatch Logs:
₹20,000
44. Budget thresholds

Example monthly cost budget:

50% actual:
Inform product owner

80% actual:
Notify engineering and finance

90% forecast:
Create optimization ticket

100% actual:
Escalate

120% actual:
Executive incident review

Use both actual and forecast thresholds.

An actual 80% threshold near the end of the month may be normal.

A forecasted 120% early in the month requires attention.

45. Budget notifications are not instantaneous

AWS Budgets updates periodically. Costs can continue increasing before and after a notification is issued.

Therefore, Budgets is not an instantaneous security control for a runaway resource.

For fast operational controls, combine:

AWS Budgets
Cost Anomaly Detection
CloudWatch usage metrics
Service quotas
SCPs
Automated resource expiration
46. Budget actions

AWS Budgets can perform actions such as:

Applying an IAM policy.
Applying an SCP.
Running supported Systems Manager actions.
Targeting EC2 or RDS resources through supported action workflows.

Budget actions can be automatic or require approval.

47. Safe budget action

Sandbox example:

Budget exceeds 120%
      |
      v
Apply restrictive IAM policy
      |
      v
Prevent new expensive resources

Production anti-pattern:

Budget exceeds threshold
      |
      v
Immediately stop production database

Budget actions must not sacrifice critical service availability.

48. Why stopping an Auto Scaling instance may fail

Suppose a budget action stops one EC2 instance:

Auto Scaling desired capacity = 5

Auto Scaling detects a missing instance and launches a replacement.

Result:

Spend continues

Budget-action design must understand the controlling service. AWS specifically warns that stopping individual EC2 or RDS resources may not be effective when an Auto Scaling or other controller recreates capacity.

49. Budget ownership

Every budget needs:

Owner
Escalation route
Threshold rationale
Notification recipients
Expected response
Review frequency

A budget email sent to an unmonitored mailbox is not governance.

Part 6 — Cost Anomaly Detection
50. What is Cost Anomaly Detection?

AWS Cost Anomaly Detection uses machine-learning models to identify unusual spending patterns.

It provides:

Cost monitors.
Alert subscriptions.
Root-cause dimensions.
Estimated financial impact.
Percentage impact.
Email, SNS and notification integrations.

Root causes can be ranked across dimensions such as service, account, Region and usage type.

51. Budgets versus anomaly detection
Budget
Did spending cross a known threshold?
Anomaly detection
Is spending unusual compared with expected behaviour?

Example:

Budget:
₹1,000,000

Unexpected daily cost:
₹80,000

Month projection:
Still below budget

The budget may not alert.

Anomaly detection may identify the unusual spike.

Use both.

52. Cost monitor types

Depending on account context, monitors can be based on:

AWS services.
Linked accounts.
Cost allocation tags.
Cost Categories.

Monitors for linked accounts, cost-allocation tags and Cost Categories are created from the Organizations management account.

53. Alert subscriptions

An alert subscription defines:

Which monitors
Financial threshold
Frequency
Recipients
Delivery method

Current API documentation supports email for daily or weekly subscriptions and SNS for immediate-frequency subscriptions.

54. Example anomaly architecture
Cost Anomaly Detection
        |
        v
Immediate SNS subscription
        |
        v
Event processing
        |
        ├── Slack/Chat notification
        ├── Email
        ├── FinOps ticket
        └── Lambda enrichment

Enrichment can add:

Account owner.
Product.
Cost center.
Recent deployments.
CloudTrail changes.
Resource tags.
55. Anomaly investigation

When an anomaly occurs:

1. Review financial impact.

2. Identify service.

3. Identify account.

4. Identify Region.

5. Identify usage type.

6. Compare with deployments.

7. Inspect resource creation.

8. Determine:
   Expected growth
   Misconfiguration
   Security incident
   Billing adjustment

Example:

Service:
EC2

Region:
Previously unused Region

Usage type:
GPU instance hours

Account:
Sandbox

Likely cause:
Compromised or misused credentials
56. Anomaly threshold design

Too low:

Alert on every ₹10 variation

Result:

Alert fatigue.
Ignored notifications.
High investigation overhead.

Too high:

Alert only above ₹1,000,000

Result:

Small but important workloads are missed.

Use different monitors for:

Organization.
Production products.
Sandbox accounts.
High-risk services.
Cost Categories.
Part 7 — AWS purchasing models
57. Main EC2 purchasing options
On-Demand
Savings Plans
Reserved Instances
Spot Instances
Dedicated Hosts/Instances
Capacity Reservations

Each solves a different problem.

58. On-Demand

On-Demand provides compute capacity without a long-term commitment.

Use for:

New workloads.
Unpredictable usage.
Short-term systems.
Temporary migration.
Burst capacity.
Baseline measurement before commitment.

On-Demand EC2 usage is billed without requiring a term commitment.

59. Savings Plans mental model

A Savings Plan is:

A commitment to spend a consistent amount per hour
on eligible usage
for a one-year or three-year term

It is not:

A specific server reservation

If you commit:

$10/hour

then eligible usage up to the commitment receives Savings Plans pricing.

Eligible usage beyond the commitment is generally billed at other applicable rates.

60. Current Savings Plans types

As of August 2026, AWS documents four Savings Plans types:

Compute Savings Plans
EC2 Instance Savings Plans
Database Savings Plans
SageMaker AI Savings Plans

61. Compute Savings Plans

Compute Savings Plans provide the most flexibility.

They can apply to eligible:

EC2
Fargate
Lambda

and remain applicable across EC2:

Instance family.
Size.
Region.
Operating system.
Tenancy.

Compute Savings Plans can provide lower discounts than more restrictive EC2 Instance Savings Plans, but they offer much greater architectural flexibility.

62. EC2 Instance Savings Plans

EC2 Instance Savings Plans apply to a chosen:

EC2 instance family
+
AWS Region

Example:

m7g usage in ap-south-1

You can change eligible sizes and certain operating-system or tenancy characteristics while retaining the applicable plan rate, but moving to another instance family or Region can lose coverage.

Use when:

The EC2 family is stable.
The Region is stable.
Higher discount is valued over flexibility.
Workload is unlikely to move to Fargate or Lambda.
63. Database Savings Plans

Database Savings Plans are a newer commitment type covering eligible usage across several AWS database and analytics services.

Current documentation lists eligible services including:

Aurora.
RDS.
DynamoDB.
ElastiCache.
DocumentDB.
Neptune.
Keyspaces.
Timestream.
Database Migration Service.
OpenSearch Service.

AWS documents potential savings of up to 35%, depending on eligible usage and plan conditions.

64. SageMaker AI Savings Plans

SageMaker AI Savings Plans apply discounted rates to eligible SageMaker AI instance usage with flexibility across:

Instance family.
Size.
Component.
Region.

They are useful for stable machine-learning training, hosting or processing baselines.

65. Savings Plans term and payment

Savings Plans support:

One-year term
Three-year term

Payment options:

No Upfront
Partial Upfront
All Upfront

Longer terms and higher upfront payment commonly provide greater discounts but increase commitment risk. AWS purchase analysis supports the four plan types, one- or three-year terms and multiple payment options.

66. Savings Plans coverage

Coverage asks:

What percentage of eligible usage
was covered by Savings Plans?

Example:

Eligible compute spend:
₹1,000,000

Covered:
₹800,000

Coverage:
80%

Low coverage may mean:

Commitment is too small.
New workload launched.
Existing plan expired.
Usage moved outside an EC2 Instance Savings Plan’s family or Region.
67. Savings Plans utilization

Utilization asks:

What percentage of the purchased hourly commitment
was actually consumed?

Example:

Commitment:
₹100/hour

Eligible use:
₹70/hour

Utilization:
70%

The unused commitment is still paid.

High coverage with low utilization can occur if accounting views are misunderstood, but operationally the main objective is:

High utilization
+
Appropriate coverage
68. Do not buy 100% baseline immediately

Suppose compute usage varies:

Minimum:
₹100/hour

Normal:
₹180/hour

Peak:
₹400/hour

Safer first commitment:

₹70–₹90/hour

rather than:

₹180/hour

Reasons:

Architecture may change.
Instances may be rightsized.
Workload may migrate.
Business demand may fall.
Region may change.
New Graviton types may reduce spend.

Commit only to the highly stable baseline.

69. Rightsize before committing

Bad sequence:

1. Buy three-year commitment.

2. Discover instances are 50% oversized.

3. Rightsize.

4. Commitment becomes underutilized.

Better:

1. Remove idle resources.

2. Rightsize.

3. Stabilize architecture.

4. Measure baseline.

5. Purchase commitment gradually.
70. Commitment laddering

Instead of one large purchase:

Buy 100% three-year commitment today

use:

Purchase 1:
Stable base usage

Purchase 2:
Additional proven growth

Purchase 3:
Replace expiring commitment

Benefits:

Reduces timing risk.
Creates multiple expiry dates.
Allows architecture changes.
Improves flexibility.
71. Savings Plans purchase analysis

AWS provides recommendations and purchase analysis based on historical usage.

Current purchase analysis supports:

Payer or linked-account analysis.
One- or three-year terms.
Payment options.
Lookback periods.
Excluding commitments nearing expiration.

Recommendations are decision support—not automatic approval.

Review:

Planned migrations
Seasonality
Rightsizing
Business forecast
Architecture changes
Existing commitments
72. Reserved Instances

An EC2 Reserved Instance is primarily a billing discount—not a physical running instance.

The discount automatically applies to matching On-Demand usage.

You continue to pay for the reservation term regardless of whether matching usage exists.

73. Standard versus Convertible RIs
Standard RI
Greater discount.
More restrictive.
Cannot be exchanged for another offering class/family through Convertible exchange.
Can be modified within supported limits.
Convertible RI
Lower discount.
Can be exchanged for another compatible Convertible RI.
Better for changing infrastructure.

AWS distinguishes Standard and Convertible offerings based largely on discount level and exchange flexibility.

74. Regional versus zonal RIs
Regional RI

Provides a Regional billing benefit and may support instance-size flexibility where applicable.

Zonal RI

Applies to a specific Availability Zone and includes a capacity-reservation benefit for the matching configuration.

AWS charges the same reservation price based on scope, but Regional and zonal reservations have different flexibility and capacity characteristics.

75. Reserved Instance versus Capacity Reservation
Reserved Instance
Primary purpose:
Billing discount
On-Demand Capacity Reservation
Primary purpose:
Reserve actual EC2 capacity in one AZ

A Capacity Reservation can be created for business-critical capacity assurance without requiring a long commitment term.

You can combine:

Capacity Reservation
+
Savings Plans or matching RI discount

where applicable.

76. When RIs remain useful

RIs may still be suitable for:

Stable service-specific usage.
Capacity reservations.
Services with reservation models.
Existing commitment portfolios.
Workloads that precisely match reservation attributes.

Savings Plans are often operationally simpler for compute because the commitment is based on eligible spend rather than a fixed instance configuration.

Part 8 — EC2 Spot Instances
77. What is Spot?

Spot Instances use spare EC2 capacity at substantial discounts compared with On-Demand pricing.

The tradeoff:

AWS can interrupt the capacity
when it is needed elsewhere.

AWS describes potential Spot savings of up to 90%, but workloads must be fault tolerant.

78. Suitable Spot workloads

Good candidates:

CI/CD agents
Batch processing
Rendering
Stateless web workers
Container tasks
Machine-learning training
Data transformation
Queue consumers
Distributed computation

Poor candidates without additional architecture:

Single database server
One-instance stateful application
Non-checkpointed long-running job
Legacy license-bound server
Workload unable to restart
79. Spot interruption notice

EC2 generally provides a two-minute interruption warning before stopping or terminating a Spot Instance.

The notice is available through:

EventBridge.
Instance metadata.

Hibernation is an exception: the interruption begins immediately rather than providing a full two-minute warning. Notices are best effort.

80. Rebalance recommendation

A rebalance recommendation can indicate elevated interruption risk before the two-minute interruption notice.

Auto Scaling and fleet mechanisms can use Capacity Rebalancing to launch replacement capacity proactively.

81. Diversify Spot capacity

Do not request only:

c7g.large
in ap-south-1a

Use several compatible:

Instance families.
Sizes.
Availability Zones.

Example:

c7g.large
c7g.xlarge
c6g.large
c6g.xlarge
m7g.large
m6g.large

Each instance type and AZ combination forms a separate Spot capacity pool.

More pools usually improve capacity availability.

82. Spot allocation strategy

AWS recommends price-capacity-optimized or capacity-oriented strategies over lowest-price-only selection.

The lowest-price strategy has the highest interruption risk and is not recommended for most resilient workloads.

83. Mixed-instance Auto Scaling

Example:

Base capacity:
2 On-Demand instances

Additional capacity:
70% Spot
30% On-Demand

This gives:

Stable baseline.
Lower scale-out cost.
Better resilience to Spot interruptions.
Flexible instance selection.
84. Spot termination handling
Rebalance or interruption event
        |
        v
Mark instance unhealthy/draining
        |
        v
Stop accepting new work
        |
        v
Checkpoint current work
        |
        v
Deregister from load balancer
        |
        v
Launch replacement

For SQS workers:

Do not delete message
until work succeeds.

If the worker is interrupted, visibility timeout eventually allows another worker to retry.

Part 9 — Cost Optimization Hub
85. What is Cost Optimization Hub?

Cost Optimization Hub consolidates and prioritizes optimization recommendations across AWS accounts and Regions.

It can aggregate recommendations for:

Rightsizing.
Idle-resource deletion.
Savings Plans.
Reserved Instances.

It accounts for existing commercial terms and deduplicates related savings opportunities.

86. Why aggregation matters

Without Cost Optimization Hub:

Compute Optimizer:
Downsize EC2

Cost Explorer:
Buy Savings Plan

Trusted Advisor:
Delete idle EC2

The estimated savings may overlap.

Example:

Current EC2:
₹100,000/month

Rightsize:
Save ₹30,000

Savings Plan:
Save ₹25,000

Naively adding:

₹55,000

may overstate savings because the Savings Plan would apply to the smaller rightsized baseline.

Cost Optimization Hub helps aggregate and deduplicate overlapping opportunities.

87. Prioritization dimensions

Recommendations can be grouped by dimensions such as:

Account.
Region.
Resource type.
Recommended action.
Implementation effort.
Restart requirement.
Rollback capability.

Use these to build an optimization backlog.

Part 10 — AWS Compute Optimizer
88. What is Compute Optimizer?

Compute Optimizer analyzes resource configuration and utilization metrics to generate rightsizing and idle-resource recommendations.

It reports whether resources appear:

Optimized.
Overprovisioned.
Underprovisioned.
Idle.

89. Supported resources

Current Compute Optimizer coverage includes resources such as:

EC2 instances
EC2 Auto Scaling groups
EBS volumes
Lambda functions
ECS services on Fargate
Aurora and RDS databases
RDS storage
Aurora clusters
NAT Gateways for idle detection

Support varies by resource subtype, Region and required metric history.

90. Metrics requirement

Compute Optimizer needs sufficient CloudWatch utilization data.

Different resource types have different monitoring requirements.

For EC2, memory analysis commonly requires the CloudWatch Agent because standard EC2 metrics do not include guest operating-system memory utilization.

91. Enhanced infrastructure metrics

Longer historical analysis can improve recommendations for:

Seasonal workloads.
Monthly jobs.
Irregular peaks.
Business-week patterns.

Evaluate the cost of enhanced metrics against the expected rightsizing benefit.

92. Performance risk

Do not select only the recommendation with the highest estimated savings.

Review:

CPU risk
Memory risk
Network risk
Storage I/O risk
Peak utilization
Autoscaling behaviour
Business criticality

A recommendation that saves 30% but has high performance risk may be unsuitable.

93. Rightsizing preferences

Compute Optimizer lets you adjust recommendation preferences such as:

CPU headroom.
Memory headroom.
Utilization thresholds.
Preferred instance families.
Lookback periods.

Example:

Mission-critical API:
30% headroom

Batch worker:
10% headroom
94. EC2 rightsizing workflow
1. Review recommendation.

2. Check CPU and memory history.

3. Check network and disk throughput.

4. Check p95/p99 application latency.

5. Confirm burst behaviour.

6. Test new instance type in staging.

7. Deploy canary.

8. Monitor.

9. Roll out.

10. Measure realized savings.
95. Graviton optimization

Migrating compatible workloads from x86 to AWS Graviton can improve price-performance.

Candidates:

Java.
Node.js.
Python.
Go.
Containerized Linux applications.
Open-source databases.
Stateless web services.

Validate:

Container architecture.
Native dependencies.
Third-party agents.
Build pipeline.
License support.
Performance tests.

For your Node.js TodoApp:

Build multi-architecture image:
linux/amd64
linux/arm64

Then benchmark an appropriate Graviton instance family.

96. EBS rightsizing

Common EBS waste:

Unattached volumes
Overprovisioned gp3 capacity
Excess IOPS
Excess throughput
Old snapshots
Large root disks
Unused provisioned IOPS volumes

For gp3, storage, IOPS and throughput can be configured independently.

Do not assume reducing volume size is always easy: EBS volumes can be expanded, but shrinking generally requires creating a smaller volume and migrating data.

97. Lambda optimization

Lambda cost depends mainly on:

Number of requests.
Allocated memory.
Execution duration.
Architecture.
Provisioned concurrency.
Ephemeral storage where applicable.
Network/data transfer.

Increasing memory can sometimes reduce total cost if the function completes much faster.

Compute Optimizer provides Lambda memory-size recommendations for eligible functions.

98. ECS Fargate optimization

Compute Optimizer can recommend:

Task CPU.
Task memory.
Container CPU.
Container memory.
Container memory reservation.

Example:

Current task:
2 vCPU
4 GB RAM

Observed:
20% CPU
35% memory

Potential:
1 vCPU
2 GB RAM

Test for:

Traffic peaks.
Garbage collection.
Startup spikes.
Deployment overlap.
Background jobs.
99. RDS and Aurora optimization

Review:

CPU
Memory pressure
Connections
Read/write latency
IOPS
Storage throughput
Replica usage
Instance class
Multi-AZ requirement
Serverless capacity
Reserved or Savings Plan coverage

Do not downsize only from average CPU.

Databases can be constrained by:

Memory.
Cache hit ratio.
Storage latency.
Connections.
Locks.
Checkpoint activity.
100. NAT Gateway optimization

Common NAT costs:

Hourly NAT Gateway charge
Data processing through NAT
Cross-AZ transfer to NAT
Internet transfer

Mitigations:

One NAT per AZ for resilience and to avoid cross-AZ routing.
Gateway endpoints for S3 and DynamoDB.
Interface endpoints for high-volume AWS APIs where economically justified.
Avoid downloading large artifacts repeatedly.
Use CloudFront for public delivery.
Route private service traffic correctly.
Remove idle NAT Gateways.

Compute Optimizer can identify idle NAT Gateways.

Part 11 — Trusted Advisor
101. What is Trusted Advisor?

Trusted Advisor provides recommendations across categories such as:

Cost optimization.
Performance.
Security.
Fault tolerance.
Service limits.

Cost checks may identify idle or underused resources.

Current availability and automatic refresh behaviour depend on the AWS Support plan. AWS documentation identifies broader Trusted Advisor access and weekly automatic refresh for qualifying Business Support+, Enterprise Support or Unified Operations plans.

102. Compute Optimizer versus Trusted Advisor
Compute Optimizer
Detailed utilization-based rightsizing
Trusted Advisor
Broader best-practice checks
Cost Optimization Hub
Aggregates and prioritizes optimization opportunities

Use all three where available.

Part 12 — Service-specific optimization
103. EC2 optimization checklist
[ ] Delete unused instances
[ ] Stop scheduled nonproduction capacity
[ ] Right-size CPU and memory
[ ] Use Auto Scaling
[ ] Use Graviton where compatible
[ ] Use Spot for interruptible work
[ ] Use commitments for stable baseline
[ ] Remove unused Elastic IPs
[ ] Delete unattached EBS volumes
[ ] Review Dedicated tenancy
[ ] Modernize legacy workloads
104. Scheduled nonproduction shutdown

Example:

Development environment:
Required 10 hours/day
Monday–Friday

Hours in one week:

Required:
50 hours

Running continuously:
168 hours

Potential idle time:

118 hours

Use:

Instance Scheduler.
EventBridge Scheduler.
Lambda.
Systems Manager Automation.
Auto Scaling scheduled actions.

Do not stop stateful resources without understanding restart behaviour.

105. Kubernetes and EKS optimization

Common EKS cost drivers:

EC2 worker nodes
EKS cluster charge
EBS volumes
Load balancers
NAT Gateway
CloudWatch logs
Data transfer
Idle namespaces
Overrequested CPU/memory

Optimization:

Cluster Autoscaler or Karpenter.
Spot node pools.
Graviton nodes.
Accurate requests and limits.
Namespace chargeback.
Bin packing.
Remove idle load balancers.
Delete abandoned PVCs.
Reduce excessive logging.
Use scheduled scaling for nonproduction.
106. Kubernetes requests create hidden waste

Container usage:

CPU actual:
100 millicores

CPU request:
2 cores

Scheduler reserves capacity based on request.

Even when actual usage is low, the node may appear full.

Track:

Requested CPU / Allocatable CPU
Requested memory / Allocatable memory
Actual CPU
Actual memory

Rightsizing Kubernetes requires both request-level and node-level optimization.

107. S3 cost dimensions

S3 cost can include:

Stored bytes.
Storage class.
Requests.
Retrieval.
Data transfer.
Lifecycle transitions.
Replication.
Inventory.
Analytics.
Object tags.
Incomplete multipart uploads.
108. S3 storage-class design

Example:

Hot objects:
S3 Standard

Unknown access pattern:
S3 Intelligent-Tiering

Infrequent but immediate:
S3 Standard-IA

Single-AZ recreatable:
S3 One Zone-IA

Archive:
S3 Glacier classes

Do not transition tiny short-lived objects blindly because minimum storage durations and per-object transition/request costs can outweigh savings.

109. S3 lifecycle

Example:

Day 0:
S3 Standard

Day 30:
Intelligent-Tiering or Standard-IA

Day 90:
Glacier Flexible Retrieval

Day 365:
Deep Archive

Day 2555:
Delete

Lifecycle policy should reflect:

Actual access.
Restore time.
Compliance.
Object size.
Retention.
Legal holds.
110. Incomplete multipart uploads

Large uploads can leave incomplete multipart parts consuming S3 storage.

Use a lifecycle rule:

Abort incomplete multipart upload
after 7 days

unless business requirements need a longer retry window.

111. CloudFront optimization

CloudFront can reduce:

Origin bandwidth.
Origin requests.
Compute load.
Global latency.

Optimize:

Cache-Control headers.
Cache-key design.
Compression.
Origin Shield where justified.
Price class.
Request policies.
Avoid forwarding unnecessary cookies, query strings and headers.

A cache policy that includes every request header can destroy cache efficiency.

112. Database cost optimization

Common waste:

Oversized instance class
Idle read replicas
Excess provisioned IOPS
Unused snapshots
Over-retained backups
Inefficient queries
Too many indexes
Always-on nonproduction databases

First optimize queries and schema.

A poorly indexed query can force you to buy a much larger database.

113. DynamoDB optimization

Choose according to workload:

On-demand:
Unpredictable or new traffic

Provisioned:
Predictable traffic with planned capacity

Auto Scaling:
Variable but bounded traffic

Reserved capacity or current discount option:
Stable baseline where applicable

Review:

Read/write capacity.
Global secondary indexes.
Global tables.
Point-in-time recovery.
Streams.
Backups.
Item size.
Standard versus infrequent-access table class.

Database Savings Plans now expand commitment-based options across eligible DynamoDB and other database services, but verify your exact usage eligibility before committing.

114. CloudWatch cost optimization

CloudWatch cost drivers:

Log ingestion
Log retention
Logs Insights scans
Custom metrics
High-cardinality dimensions
Detailed monitoring
Dashboards
Alarms
Trace ingestion
RUM
Synthetics

Controls:

Explicit retention.
Structured concise logs.
Avoid debug logging in production.
Appropriate log classes.
Sample traces.
Avoid per-user custom metrics.
Delete unused dashboards and alarms.
Use S3 for long-term archives.
115. Network cost optimization

Network charges often hide in:

Inter-AZ traffic.
Inter-Region traffic.
NAT Gateway processing.
Public IPv4 addresses.
Load balancers.
Transit Gateway processing.
Internet egress.
PrivateLink endpoints.
Cross-account shared services.

Create a specific Cost Explorer report:

Group by:
Usage type

Filter:
Data Transfer

Then trace each major usage type to architecture.

116. Inter-AZ architecture tradeoff

Do not eliminate all cross-AZ traffic simply to reduce cost.

Multi-AZ architecture provides resilience.

Instead:

Keep traffic zonally local where possible.
Deploy NAT Gateway per AZ.
Use topology-aware routing.
Place consumers near data.
Avoid unnecessary repeated cross-AZ transfers.
Measure rather than guess.
117. Public IPv4 cost awareness

Review:

Unused Elastic IPs
Stopped instances retaining public IPv4 allocation
Public addresses for private workloads
Internet-facing load balancers no longer used

Prefer:

Private subnets.
SSM Session Manager.
NAT or egress architectures.
IPv6 where appropriate.
Load balancers instead of public IP per instance.
Part 13 — Unit economics
118. Why total monthly cost is insufficient

Suppose:

January cost:
₹500,000

February cost:
₹650,000

This looks worse.

But:

January users:
10,000

February users:
20,000

Cost per user:

January:
₹50

February:
₹32.50

Total cost increased, but economic efficiency improved.

119. Unit-cost examples
Cost per active user
Cost per API request
Cost per todo created
Cost per customer
Cost per transaction
Cost per GB processed
Cost per ML inference
Cost per report
Cost per deployment
Cost per build minute

Choose a unit tied to business value.

120. TodoApp unit economics

Assume monthly:

AWS amortized cost:
₹300,000

Active users:
50,000

Todos created:
2,000,000

API requests:
100,000,000

Metrics:

Cost per active user:
₹300,000 / 50,000
= ₹6

Cost per todo:
₹300,000 / 2,000,000
= ₹0.15

Cost per 1,000 API requests:
₹300,000 / 100,000
= ₹3
121. Allocate shared costs into unit cost

Product cost should include appropriate shares of:

Application account
Network account
Security services
Monitoring
CI/CD
Backups
Support
Shared database
Platform engineering

Otherwise the product appears artificially cheap.

122. Marginal versus average cost
Average cost
Total cost / Total units
Marginal cost
Additional cost of serving one additional unit

Example:

ECS currently has unused capacity.

One additional API request may cost almost nothing.

But at the scaling threshold, additional requests may trigger another task or database tier.

Understand both for pricing and capacity planning.

123. Cost-efficiency KPIs

Recommended KPIs:

Cost per customer
Cost per transaction
Savings Plans utilization
Savings Plans coverage
Idle-resource cost
Rightsizing opportunity
Tag coverage
Forecast variance
Anomaly resolution time
Optimization realized savings
Part 14 — FinOps operating model
124. Roles and responsibilities
Engineering
Right-size resources.
Improve architecture.
Own resource tags.
Delete waste.
Implement Spot and scaling.
Measure unit cost.
Finance
Budget and forecast.
Manage accounting views.
Track invoices.
Allocate costs.
Validate realized savings.
Product
Connect cost to customer value.
Decide service tiers.
Prioritize optimization.
Understand demand.
Procurement
Review commitments.
Negotiate contracts.
Manage payment options.
Leadership
Set cost-efficiency targets.
Resolve ownership conflicts.
Approve major commitments.
125. FinOps meeting cadence
Daily
Critical anomaly review.
Payment or billing issues.
Runaway resources.
Weekly
Product cost trend.
New optimization opportunities.
Commitment coverage.
Idle resources.
Cost-impacting deployments.
Monthly
Forecast versus actual.
Unit-cost trend.
Showback/chargeback.
Commitment purchase review.
Realized savings.
Budget adjustments.
Quarterly
Architecture optimization.
Contract and commitment planning.
Business forecasts.
Account and Cost Category review.
126. Optimization backlog

Example:

Opportunity	Monthly saving	Effort	Risk	Owner
Delete idle NAT Gateway	High	Low	Low	Network
Right-size RDS	High	Medium	Medium	Database
Move CI to Spot	Medium	Medium	Low	DevOps
Reduce log retention	Medium	Low	Low	Platform
Buy Savings Plan	High	Low	High commitment	FinOps
Migrate to Graviton	High	High	Medium	App

Prioritize:

High saving
+
Low effort
+
Low operational risk
127. Estimated versus realized savings

Recommendation:

Estimated monthly saving:
₹100,000

After implementation:

Observed monthly saving:
₹65,000

Possible reasons:

Usage changed.
Recommendation overlapped another action.
Commitment allocation changed.
Traffic grew.
Migration was partial.
New cost appeared elsewhere.

Track realized savings from actual billing data.

128. Cost optimization without ownership fails

Every resource should have:

Application
Environment
Owner
CostCenter
ManagedBy

Every optimization recommendation should have:

Owner
Due date
Decision
Expected saving
Realized saving
Reason if rejected
Part 15 — Cost governance guardrails
129. Preventive guardrails

Examples:

SCP:
Restrict expensive instance families in sandbox

Service quota:
Limit GPU capacity

Tag policy:
Standardize ownership tags

IAM:
Require approved launch templates

Terraform policy:
Reject untagged resources
130. Detective guardrails

Examples:

AWS Config:
Resources must have required tags

Cost Anomaly Detection:
Detect unusual spend

AWS Budgets:
Alert on forecast overrun

Compute Optimizer:
Identify oversized resources

Trusted Advisor:
Identify idle resources
131. Corrective guardrails

Examples:

Stop idle development instance
Delete abandoned snapshot after approval
Apply restrictive sandbox IAM policy
Move old data to archive
Expire temporary environments

Corrective automation should:

Be reversible where possible.
Respect production exclusions.
Log every action.
Notify owners.
Use grace periods.
Support exception tags.
132. Temporary resource expiry

Add:

ExpiresAt = 2026-08-10

Automation:

Daily EventBridge schedule
        |
        v
Find expired resources
        |
        v
Notify owner
        |
        v
Grace period
        |
        v
Stop or delete

Good for:

Sandboxes.
Demo environments.
Test databases.
Temporary EC2 instances.
Proof-of-concept clusters.
133. Do not automate deletion using only a Name tag

Bad:

Delete every resource named test

Better:

Environment = sandbox
AND
AutoDelete = true
AND
ExpiresAt < today
AND
Protected != true

Then use a staged process:

Notify
Stop
Wait
Delete
Part 16 — Terraform implementation
134. Cost-allocation tags

Terraform automatically applies tags only where the provider/resource supports them.

Provider defaults:

provider "aws" {
  region = "ap-south-1"

  default_tags {
    tags = {
      ManagedBy   = "Terraform"
      Application = "TodoApp"
      Environment = "production"
      CostCenter  = "CC-1004"
      Owner       = "platform-team"
    }
  }
}

Default tags improve consistency but do not replace policy validation or tag activation in Billing.

135. AWS budget
resource "aws_budgets_budget" "todoapp_monthly" {
  name = "todoapp-production-monthly"

  budget_type = "COST"

  limit_amount = "300000"
  limit_unit   = "USD"

  time_unit = "MONTHLY"

  cost_types {
    include_credit             = true
    include_discount           = true
    include_other_subscription = true
    include_recurring          = true
    include_refund             = true
    include_subscription       = true
    include_tax                = true
    include_upfront            = true
    use_amortized              = true
    use_blended                = false
  }

  cost_filter {
    name = "TagKeyValue"

    values = [
      "user:Application$TodoApp"
    ]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"

    subscriber_email_addresses = [
      "finops@example.com"
    ]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"

    subscriber_sns_topic_arns = [
      aws_sns_topic.cost_alerts.arn
    ]
  }
}

AWS Budgets uses the configured budget currency unit. Confirm the currency and amount used by the payer’s billing model before deployment.

136. Cost anomaly monitor
resource "aws_ce_anomaly_monitor" "todoapp" {
  name = "todoapp-services"

  monitor_type = "CUSTOM"

  monitor_specification = jsonencode({
    And = [
      {
        Dimensions = {
          Key          = "LINKED_ACCOUNT"
          MatchOptions = ["EQUALS"]
          Values       = [var.todoapp_account_id]
        }
      },
      {
        Tags = {
          Key          = "Application"
          MatchOptions = ["EQUALS"]
          Values       = ["TodoApp"]
        }
      }
    ]
  })
}

Exact supported expressions depend on the Cost Explorer API and provider version.

137. Anomaly subscription
resource "aws_ce_anomaly_subscription" "immediate" {
  name = "todoapp-immediate-cost-alerts"

  frequency = "IMMEDIATE"

  monitor_arn_list = [
    aws_ce_anomaly_monitor.todoapp.arn
  ]

  threshold_expression = jsonencode({
    And = [
      {
        Dimensions = {
          Key          = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
          MatchOptions = ["GREATER_THAN_OR_EQUAL"]
          Values       = ["100"]
        }
      },
      {
        Dimensions = {
          Key          = "ANOMALY_TOTAL_IMPACT_PERCENTAGE"
          MatchOptions = ["GREATER_THAN_OR_EQUAL"]
          Values       = ["20"]
        }
      }
    ]
  })

  subscriber {
    type    = "SNS"
    address = aws_sns_topic.cost_alerts.arn
  }
}

Immediate Cost Anomaly Detection delivery uses SNS according to current subscription behaviour.

138. CUR 2.0 export

Conceptual Terraform:

resource "aws_bcmdataexports_export" "cur2" {
  export {
    name = "organization-cur2"

    data_query {
      query_statement = <<SQL
SELECT
  bill_payer_account_id,
  line_item_usage_account_id,
  line_item_usage_start_date,
  line_item_usage_end_date,
  line_item_product_code,
  line_item_usage_type,
  line_item_operation,
  line_item_unblended_cost,
  line_item_net_unblended_cost,
  resource_tags,
  cost_category
FROM COST_AND_USAGE_REPORT
SQL

      table_configurations = {
        COST_AND_USAGE_REPORT = {
          TIME_GRANULARITY = "HOURLY"
          INCLUDE_RESOURCES = "TRUE"
          INCLUDE_MANUAL_DISCOUNT_COMPATIBILITY = "FALSE"
          INCLUDE_SPLIT_COST_ALLOCATION_DATA = "TRUE"
        }
      }
    }

    destination_configurations {
      s3_destination {
        s3_bucket = aws_s3_bucket.cost_data.bucket
        s3_prefix = "cur2"
        s3_region = "ap-south-1"

        s3_output_configurations {
          compression = "PARQUET"
          format      = "PARQUET"
          output_type = "CUSTOM"
          overwrite   = "CREATE_NEW_REPORT"
        }
      }
    }

    refresh_cadence {
      frequency = "SYNCHRONOUS"
    }
  }
}

Validate the exact table configurations and SQL columns against the provider and CUR 2.0 schema pinned in your environment.

139. Cost-data S3 lifecycle
resource "aws_s3_bucket_lifecycle_configuration" "cost_data" {
  bucket = aws_s3_bucket.cost_data.id

  rule {
    id     = "cost-data-lifecycle"
    status = "Enabled"

    filter {
      prefix = "cur2/"
    }

    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 365
      storage_class = "GLACIER_IR"
    }

    expiration {
      days = 2555
    }
  }
}

Retention should follow finance, tax, contract and audit requirements.

140. Sandbox instance restriction

Example SCP concept:

resource "aws_organizations_policy" "sandbox_instance_types" {
  name = "SandboxInstanceTypeRestriction"

  type = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Sid    = "RestrictExpensiveInstances"
      Effect = "Deny"

      Action = [
        "ec2:RunInstances"
      ]

      Resource = [
        "arn:aws:ec2:*:*:instance/*"
      ]

      Condition = {
        ForAnyValue_StringNotLike = {
          "ec2:InstanceType" = [
            "t3.*",
            "t4g.*",
            "m7g.large"
          ]
        }
      }
    }]
  })
}

Test SCP condition syntax and RunInstances resource behaviour in a policy-staging OU before production use.

Part 17 — Hands-on FinOps lab
141. Lab goal

Build a practical cost-control baseline:

Cost Explorer analysis
Monthly budget
SNS cost-alert topic
Cost Anomaly Detection monitor
Resource inventory
Idle-resource checks
Cleanup review

This lab should not create expensive workload resources.

142. Confirm caller identity
aws sts get-caller-identity

Record:

Account ID
Role ARN
Organization context

Billing and cost-management permissions are often restricted to finance or management-account roles.

143. Query month-to-date cost

Set dates:

START_DATE=$(date -u +%Y-%m-01)
END_DATE=$(date -u -d tomorrow +%Y-%m-%d)

Query:

aws ce get-cost-and-usage \
  --time-period \
    Start="$START_DATE",End="$END_DATE" \
  --granularity DAILY \
  --metrics \
    UnblendedCost \
    AmortizedCost \
  --group-by \
    Type=DIMENSION,Key=SERVICE

On systems where GNU date is unavailable, calculate the ISO dates manually.

144. Find top services
aws ce get-cost-and-usage \
  --time-period \
    Start="$START_DATE",End="$END_DATE" \
  --granularity MONTHLY \
  --metrics AmortizedCost \
  --group-by \
    Type=DIMENSION,Key=SERVICE \
  --query '
    ResultsByTime[0].Groups[].{
      Service:Keys[0],
      Cost:Metrics.AmortizedCost.Amount
    }'

Sort with jq:

aws ce get-cost-and-usage \
  --time-period \
    Start="$START_DATE",End="$END_DATE" \
  --granularity MONTHLY \
  --metrics AmortizedCost \
  --group-by \
    Type=DIMENSION,Key=SERVICE \
  --output json |
jq '
  .ResultsByTime[0].Groups
  | map({
      service: .Keys[0],
      cost: (.Metrics.AmortizedCost.Amount | tonumber)
    })
  | sort_by(.cost)
  | reverse
'
145. Create SNS topic
COST_TOPIC_ARN=$(
  aws sns create-topic \
    --name finops-cost-alerts \
    --region ap-south-1 \
    --query TopicArn \
    --output text
)

echo "$COST_TOPIC_ARN"

Add a controlled subscription:

aws sns subscribe \
  --topic-arn "$COST_TOPIC_ARN" \
  --protocol email \
  --notification-endpoint "finops@example.com" \
  --region ap-south-1

The recipient must confirm the subscription.

146. Create a cost budget

Prepare:

cat > /tmp/budget.json <<'EOF'
{
  "BudgetName": "finops-lab-monthly",
  "BudgetLimit": {
    "Amount": "100",
    "Unit": "USD"
  },
  "BudgetType": "COST",
  "TimeUnit": "MONTHLY",
  "CostTypes": {
    "IncludeTax": true,
    "IncludeSubscription": true,
    "UseBlended": false,
    "UseAmortized": true
  }
}
EOF

Notification:

cat > /tmp/budget-notification.json <<EOF
{
  "Notification": {
    "NotificationType": "FORECASTED",
    "ComparisonOperator": "GREATER_THAN",
    "Threshold": 80,
    "ThresholdType": "PERCENTAGE"
  },
  "Subscribers": [
    {
      "SubscriptionType": "SNS",
      "Address": "${COST_TOPIC_ARN}"
    }
  ]
}
EOF

Create:

ACCOUNT_ID=$(
  aws sts get-caller-identity \
    --query Account \
    --output text
)

aws budgets create-budget \
  --account-id "$ACCOUNT_ID" \
  --budget file:///tmp/budget.json \
  --notifications-with-subscribers \
    file:///tmp/budget-notification.json

Ensure the amount is appropriate for the account before creating the budget.

147. Inspect budgets
aws budgets describe-budgets \
  --account-id "$ACCOUNT_ID"

Inspect calculated values:

ActualSpend
ForecastedSpend
BudgetLimit
TimePeriod
148. List anomaly monitors
aws ce get-anomaly-monitors

List subscriptions:

aws ce get-anomaly-subscriptions

In an Organizations management account, create monitors for specific linked accounts, Cost Categories or tags according to your allocation design.

149. Find unattached EBS volumes
aws ec2 describe-volumes \
  --filters Name=status,Values=available \
  --region ap-south-1 \
  --query '
    Volumes[].{
      VolumeId:VolumeId,
      SizeGiB:Size,
      Type:VolumeType,
      Created:CreateTime,
      Encrypted:Encrypted
    }' \
  --output table

Do not delete automatically.

First determine:

Owner.
Last attached instance.
Snapshot requirement.
Data classification.
Retention requirement.
150. Find stopped instances
aws ec2 describe-instances \
  --filters Name=instance-state-name,Values=stopped \
  --region ap-south-1 \
  --query '
    Reservations[].Instances[].{
      InstanceId:InstanceId,
      Type:InstanceType,
      LaunchTime:LaunchTime,
      Name:Tags[?Key==`Name`]|[0].Value
    }' \
  --output table

Stopped instances do not incur normal compute charges, but their EBS volumes, snapshots, Elastic IPs and related resources may still cost money.

151. Find unused Elastic IPs
aws ec2 describe-addresses \
  --region ap-south-1 \
  --query '
    Addresses[?AssociationId==null].{
      AllocationId:AllocationId,
      PublicIp:PublicIp,
      Domain:Domain
    }' \
  --output table

Review before release because DNS, firewall allow lists or DR plans may reference the address.

152. Cleanup lab budget
aws budgets delete-budget \
  --account-id "$ACCOUNT_ID" \
  --budget-name finops-lab-monthly

Delete topic after removing subscriptions:

aws sns delete-topic \
  --topic-arn "$COST_TOPIC_ARN" \
  --region ap-south-1

Remove temporary files:

rm -f \
  /tmp/budget.json \
  /tmp/budget-notification.json
Part 18 — Troubleshooting
153. Cost Explorer shows no data

Check:

Cost Explorer enabled.
Initial data preparation completed.
Correct payer/member account.
Billing permissions.
Billing view.
Date range.
Filter.
New account with little usage.
Organization membership change.

Initial Cost Explorer data preparation is not instantaneous.

154. Cost totals differ between reports

Possible reasons:

Unblended versus amortized cost
Net versus gross cost
Credits
Refunds
Taxes
Support
Commitments
Different time zones
Different date ranges
Different filters
Estimated versus finalized bill

Before comparing two reports, align:

Metric.
Time range.
Granularity.
Filters.
Currency.
Billing view.
Refresh time.
155. CUR 2.0 export is empty

Check:

Initial 24-hour delivery period.
S3 bucket policy.
Export Region.
Export status.
Query statement.
Table configuration.
S3 prefix.
KMS permissions.
Organization access.
Export refresh status files.

AWS provides export-status and delivery artifacts for troubleshooting.

156. Athena query returns duplicate-looking cost

Possible causes:

Reading several report versions.
S3 overwrite/create-new-report mode.
Duplicate crawler partitions.
Mixing estimated and finalized files.
Joining without unique line-item keys.
Reading legacy CUR and CUR 2.0 together.

Use the export manifest/status data and partition strategy deliberately.

157. Cost-allocation tag missing

Check:

Tag exists on resource
Tag was activated for cost allocation
Activation occurred before desired usage
Resource type supports tags
Tag key case
Billing data refresh
Correct payer account

Tags may not retroactively reclassify historical spending from before activation.

158. Budget did not alert immediately

AWS Budgets is periodically updated and is not a real-time control.

Check:

Notification threshold.
Actual versus forecast.
Subscriber confirmation.
SNS policy.
Budget filter.
Cost metric.
Update delay.
Currency.
Billing view.

159. Budget action failed

Check:

Budget action role.
Trust for Budgets service.
iam:PassRole.
Action approval state.
IAM/SCP target exists.
EC2/RDS target state.
SSM Automation permissions.
Same-account requirements.
CloudTrail budget-action history.

AWS provides budget-action history for auditing approvals and executions.

160. Anomaly monitor produces no alerts

Check:

Monitor exists.
Subscription attached.
Threshold too high.
Frequency.
Email/SNS configuration.
Monitor account.
Cost Category/tag values.
Insufficient baseline.
Usage is unusual but below notification threshold.

The anomaly-detection model can identify an anomaly without notifying when it does not cross the subscription threshold.

161. Savings Plans utilization is low

Possible causes:

Workload was stopped.
Rightsizing reduced eligible usage.
Application migrated.
Region changed under EC2 Instance plan.
Instance family changed.
Business demand fell.
Duplicate commitment was purchased.
Existing RIs absorbed usage first.

AWS billing applies eligible RIs before Savings Plans, and EC2 Instance Savings Plans before broader Compute Savings Plans.

Actions:

Review eligible usage
Review expiring commitments
Adjust future purchases
Move eligible workloads where architecturally valid
Avoid purchasing more commitment
162. Savings Plans coverage is low

Possible causes:

Usage grew.
Commitment expired.
New account usage not considered.
EC2 Instance plan does not match Region/family.
Lambda/Fargate usage increased.
Database usage is not covered by the chosen plan type.

Do not immediately purchase more.

First determine whether the growth is stable.

163. Compute Optimizer has no recommendation

Check:

Service opted in.
Resource supported.
Enough CloudWatch history.
Resource active.
Required memory metrics.
Organization trusted access.
Region support.
Resource configuration.
Recommendation preference.

Compute Optimizer requirements vary by resource type and monitoring history.

164. Rightsizing caused performance degradation

Rollback and investigate:

CPU saturation
Memory pressure
Swap
Network throughput
EBS limits
Burst credits
Connection limits
Garbage collection
Peak load
Deployment overlap

Do not treat average CPU as the only sizing metric.

165. Spot capacity is unavailable

Actions:

Increase instance-type diversity.
Use more Availability Zones.
Use attribute-based selection.
Use price-capacity-optimized.
Maintain On-Demand base capacity.
Review Spot placement score.
Reduce per-instance constraints.
Use smaller capacity units.

Spot placement scores change with real-time capacity and do not guarantee fulfillment.

166. Spot interruptions cause failed jobs

Improve:

Checkpoint frequently
Use idempotent processing
Use SQS visibility timeouts
Store state outside instance
Handle EventBridge interruption events
Enable Capacity Rebalancing
Reduce job chunk size

A workload that cannot restart safely is not ready for Spot.

167. NAT Gateway costs are unexpectedly high

Investigate:

Traffic by subnet
Traffic by destination
Cross-AZ routing
S3/ECR downloads
Container image pulls
CloudWatch/Secrets Manager traffic
Software updates
Internet downloads

Potential fixes:

S3 gateway endpoint.
DynamoDB gateway endpoint.
ECR interface endpoints plus S3 endpoint.
Local artifact caching.
Per-AZ NAT routing.
Avoid repeated package downloads.
Evaluate interface-endpoint economics.

An interface endpoint itself has hourly and data charges, so calculate the crossover point.

168. CloudWatch logs cost increased

Check:

New debug logging.
Exception loop.
Duplicate log agents.
Multiline stack traces.
High-volume access logs.
No retention.
High-cardinality EMF.
Fargate sidecar duplication.
Trace/log correlation data.

Use Logs Insights to identify the noisiest service, stream and message pattern.

Part 19 — Production FinOps checklist
169. Visibility checklist
[ ] Cost Explorer is enabled
[ ] Data Export CUR 2.0 is configured
[ ] Cost data is stored in a protected S3 bucket
[ ] Athena queries are available
[ ] Executive cost dashboard exists
[ ] Engineering cost dashboard exists
[ ] Amortized cost is used for product economics
[ ] Invoice cost is reconciled separately
[ ] Cost data access follows least privilege
[ ] Historical retention meets finance requirements
170. Allocation checklist
[ ] Every account has an owner
[ ] Every account has a cost center
[ ] Required resource tags are documented
[ ] Cost allocation tags are activated
[ ] Tag compliance is measured
[ ] Account tags are activated where useful
[ ] Cost Categories map technical to business ownership
[ ] Shared costs have allocation rules
[ ] Showback or chargeback model is documented
[ ] Untagged cost is reported
171. Monitoring checklist
[ ] Organization budget exists
[ ] Account budgets exist
[ ] Product budgets exist
[ ] Actual thresholds exist
[ ] Forecast thresholds exist
[ ] Budget owners are assigned
[ ] Cost Anomaly Detection monitors exist
[ ] Immediate high-impact anomaly alerts use SNS
[ ] Anomalies are enriched with ownership
[ ] Cost incidents have response runbooks
172. Commitment checklist
[ ] Idle resources removed before commitment purchase
[ ] Rightsizing completed before purchase
[ ] Stable baseline is measured
[ ] Savings Plans type is selected intentionally
[ ] One-year versus three-year risk is documented
[ ] Payment option is approved
[ ] Coverage is tracked
[ ] Utilization is tracked
[ ] Expiry dates are monitored
[ ] Purchases are laddered where appropriate
[ ] Forecasted architecture changes are considered
[ ] Recommendations receive finance and engineering review
173. Resource optimization checklist
[ ] Compute Optimizer is enabled
[ ] Cost Optimization Hub is enabled
[ ] Trusted Advisor checks are reviewed
[ ] EC2 is rightsized
[ ] Graviton migration is evaluated
[ ] Spot is used for interruptible workloads
[ ] EBS volumes and snapshots are reviewed
[ ] Nonproduction scheduling is automated
[ ] RDS/Aurora is rightsized
[ ] S3 lifecycle policies exist
[ ] NAT Gateway processing is reviewed
[ ] CloudWatch retention is explicit
[ ] Idle load balancers and public IPs are removed
174. Operational checklist
[ ] Weekly optimization review occurs
[ ] Monthly forecast review occurs
[ ] Unit-cost KPIs are tracked
[ ] Estimated and realized savings are separated
[ ] Every optimization has an owner
[ ] Temporary resources have expiry dates
[ ] Production deletion requires approval
[ ] Cost policy changes are version controlled
[ ] Finance and engineering use the same definitions
[ ] Cost optimization does not violate resilience requirements
175. Certification-focused understanding
AWS Cloud Practitioner

Understand:

Cost Explorer
AWS Budgets
Cost Anomaly Detection
Savings Plans
Reserved Instances
Spot Instances
Compute Optimizer
Solutions Architect Associate

Understand:

On-Demand versus Spot
Savings Plans flexibility
Regional versus zonal RIs
S3 storage classes
Auto Scaling
Rightsizing
NAT/data-transfer costs
Cost-allocation tags
DevOps Engineer Professional

Understand:

CUR 2.0 and Data Exports
Athena cost analysis
Cost Categories
Budget actions
Anomaly monitors
Commitment coverage/utilization
Cost Optimization Hub
Organization-wide FinOps
Spot interruption handling
Unit economics
Automated cost governance
176. Interview questions
Question 1: What is FinOps?

Answer:

FinOps is a collaborative operating model in which engineering, finance, product and business teams share responsibility for maximizing the business value of cloud spending.

Question 2: What is the difference between cost reduction and optimization?

Answer:

Cost reduction lowers spending. Cost optimization lowers sustainable spending while maintaining required reliability, security, performance and business outcomes.

Question 3: What is Cost Explorer?

Answer:

It is an AWS tool for interactive cost and usage analysis, filtering, grouping, forecasting and commitment reporting.

Question 4: What is CUR 2.0?

Answer:

Cost and Usage Report 2.0 is AWS’s recommended detailed billing export format, delivered through AWS Data Exports with a more consistent and compact schema.

Question 5: What is amortized cost?

Answer:

It distributes upfront and recurring commitment charges over the period in which the commitment provides value.

Question 6: What are cost-allocation tags?

Answer:

They are activated resource tags used to organize and analyze AWS spending in cost-management reports.

Question 7: What is a Cost Category?

Answer:

It is a business-oriented cost grouping created using rules based on accounts, services, tags and other billing dimensions.

Question 8: What is the difference between showback and chargeback?

Answer:

Showback reports costs to teams. Chargeback financially allocates or recovers those costs from the teams.

Question 9: What is the difference between Budgets and Cost Anomaly Detection?

Answer:

Budgets alert when known thresholds are crossed. Anomaly Detection identifies spending that is unusual compared with learned behaviour.

Question 10: What are the four Savings Plans types?

Answer:

Compute, EC2 Instance, Database and SageMaker AI Savings Plans.

Question 11: What is Savings Plans coverage?

Answer:

It is the percentage of eligible usage receiving Savings Plans pricing.

Question 12: What is Savings Plans utilization?

Answer:

It is the percentage of the purchased hourly commitment that was consumed by eligible usage.

Question 13: Why rightsize before purchasing commitments?

Answer:

Otherwise you may commit to usage that disappears after optimization, creating long-term underutilization.

Question 14: What is the difference between a Savings Plan and an RI?

Answer:

A Savings Plan is an hourly eligible-spend commitment. An RI is a service-specific billing reservation matching defined attributes.

Question 15: What is the difference between an RI and Capacity Reservation?

Answer:

An RI mainly provides a billing discount. A Capacity Reservation reserves actual EC2 capacity in a specific Availability Zone.

Question 16: When should Spot be used?

Answer:

For fault-tolerant, interruptible workloads such as batch jobs, CI/CD agents, queue workers and stateless compute.

Question 17: What is Cost Optimization Hub?

Answer:

It centralizes and prioritizes rightsizing, idle-resource and commitment recommendations while accounting for overlapping savings and existing discounts.

Question 18: What is Compute Optimizer?

Answer:

It analyzes configuration and utilization metrics to recommend better resource sizes and identify idle resources.

Question 19: What is unit economics?

Answer:

It measures cloud cost per meaningful business unit, such as cost per user, request, transaction or GB processed.

Question 20: What is the most important commitment-purchase principle?

Answer:

Commit only to a stable, rightsized baseline that the organization is highly confident it will continue using.

177. Never-forget revision
Cost Explorer:
Interactive cost analysis.

Data Exports:
Detailed billing datasets delivered to S3.

CUR 2.0:
Recommended AWS detailed cost and usage schema.

Cost allocation tag:
Activated resource tag used in billing.

Cost Category:
Business grouping of AWS costs.

Showback:
Report cost to owner.

Chargeback:
Financially allocate cost to owner.

Budget:
Known financial threshold.

Anomaly:
Unexpected cost behaviour.

On-Demand:
No term commitment.

Savings Plan:
Hourly eligible-usage commitment.

Coverage:
Eligible usage receiving a discount.

Utilization:
Purchased commitment being consumed.

Reserved Instance:
Matching usage billing discount.

Capacity Reservation:
Actual EC2 capacity reservation.

Spot:
Discounted interruptible EC2 capacity.

Compute Optimizer:
Rightsizing recommendations.

Cost Optimization Hub:
Aggregated optimization opportunities.

Unit cost:
Cloud cost per business outcome.
One-line memory trick
Allocate first.
Measure second.
Remove waste third.
Rightsize fourth.
Commit only after the baseline is stable.
Use Spot for interruptible work.
Track realized savings and business unit cost.
Lesson 61 outcome

You can now design FinOps where:

A monthly bill increases
    → Cost Explorer identifies the service and account.

Detailed line-item analysis is required
    → CUR 2.0 is exported to S3 and queried with Athena.

Shared network costs need allocation
    → Cost Categories and split rules assign ownership.

A product may exceed its target
    → AWS Budgets provides actual and forecast alerts.

A sudden GPU fleet appears
    → Cost Anomaly Detection identifies unusual spend.

Stable compute usage exists
    → Savings Plans reduce eligible rates.

Interruptible workers exist
    → Spot and Capacity Rebalancing reduce compute cost.

Resources are oversized
    → Compute Optimizer recommends safer configurations.

Several recommendations overlap
    → Cost Optimization Hub deduplicates and prioritizes them.

Leadership asks whether efficiency improved
    → Cost per active user and cost per transaction show value.

Next lesson: Lesson 62 — AWS Well-Architected Framework production reviews: Operational Excellence, Security, Reliability, Performance Efficiency, Cost Optimization and Sustainability, including workload reviews, risks, improvement plans and architecture governance.