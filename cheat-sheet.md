# AWS / Terraform CLI Cheat Sheet

Useful commands from the `saas-platform` project.

---

## Identity & SSO

### Login with IAM Identity Center / SSO

```bash
aws sso login --profile saas-learning
```

### Who am I?

```bash
aws sts get-caller-identity \
  --profile saas-learning
```

Useful when debugging permissions or confirming which role/account you're actually using.

### What region does this profile use?

```bash
aws configure get region \
  --profile saas-learning
```

---

# S3

## List objects recursively

```bash
aws s3 ls \
  s3://saas-platform-dev-uploads-388260576957/ \
  --recursive \
  --profile saas-learning
```

## List objects using the lower-level S3 API

```bash
aws s3api list-objects-v2 \
  --bucket saas-platform-dev-uploads-388260576957 \
  --profile saas-learning
```

## Inspect an object without downloading it

```bash
aws s3api head-object \
  --bucket saas-platform-dev-uploads-388260576957 \
  --key uploads/test.txt \
  --profile saas-learning
```

## Download an object to stdout

```bash
aws s3 cp \
  s3://saas-platform-dev-uploads-388260576957/uploads/test.txt \
  - \
  --profile saas-learning
```

### `aws s3` vs `aws s3api`

```text
aws s3
    high-level convenience commands

aws s3api
    maps more directly to S3 API operations
```

---

# S3 Presigned URLs

## Generate a presigned PUT URL with Python/boto3

```bash
AWS_PROFILE=saas-learning python - <<'PY'
import boto3

s3 = boto3.client("s3", region_name="us-east-1")

print(s3.generate_presigned_url(
    ClientMethod="put_object",
    Params={
        "Bucket": "saas-platform-dev-uploads-388260576957",
        "Key": "uploads/test.txt",
    },
    ExpiresIn=300,
))
PY
```

The identity generating the URL must itself have permission to perform the underlying operation.

For this example:

```text
s3:PutObject
```

The URL delegates that specific capability temporarily.

## Store the URL without echoing it

```bash
read -s PRESIGNED_URL
```

Paste the URL and press Enter.

## Upload through the presigned URL

```bash
echo "hello S3" > /tmp/test.txt

curl -i \
  -X PUT \
  --upload-file /tmp/test.txt \
  "$PRESIGNED_URL"
```

Important:

The presigned URL is signed for a specific S3 object key.

If the URL was created for:

```text
uploads/test.txt
```

then this:

```bash
curl --upload-file /tmp/something-else.txt "$PRESIGNED_URL"
```

still uploads to:

```text
uploads/test.txt
```

The local filename doesn't determine the S3 key.

---

# SQS

## Send a message

```bash
aws sqs send-message \
  --queue-url https://sqs.us-east-1.amazonaws.com/388260576957/saas-platform-dev-jobs \
  --message-body '{"test":"hello"}' \
  --profile saas-learning
```

Successful response includes:

```json
{
  "MD5OfMessageBody": "...",
  "MessageId": "..."
}
```

## Receive a message

```bash
aws sqs receive-message \
  --queue-url https://sqs.us-east-1.amazonaws.com/388260576957/saas-platform-dev-jobs \
  --wait-time-seconds 10 \
  --profile saas-learning
```

## Receive up to 10 messages

```bash
aws sqs receive-message \
  --queue-url https://sqs.us-east-1.amazonaws.com/388260576957/saas-platform-dev-jobs \
  --max-number-of-messages 10 \
  --wait-time-seconds 10 \
  --profile saas-learning
```

`max-number-of-messages=10` means:

```text
return UP TO 10
```

It does not guarantee that every available message will be returned.

## Include receive count

```bash
aws sqs receive-message \
  --queue-url https://sqs.us-east-1.amazonaws.com/388260576957/saas-platform-dev-jobs \
  --max-number-of-messages 10 \
  --wait-time-seconds 10 \
  --attribute-names ApproximateReceiveCount \
  --profile saas-learning
```

## Inspect all queue attributes

```bash
aws sqs get-queue-attributes \
  --queue-url https://sqs.us-east-1.amazonaws.com/388260576957/saas-platform-dev-jobs \
  --attribute-names All \
  --profile saas-learning
```

## Inspect queue depth

```bash
aws sqs get-queue-attributes \
  --queue-url https://sqs.us-east-1.amazonaws.com/388260576957/saas-platform-dev-jobs \
  --attribute-names \
    ApproximateNumberOfMessages \
    ApproximateNumberOfMessagesNotVisible \
    ApproximateNumberOfMessagesDelayed \
  --profile saas-learning
```

Meaning:

```text
ApproximateNumberOfMessages
    available to consumers

ApproximateNumberOfMessagesNotVisible
    received and currently inside visibility timeout

ApproximateNumberOfMessagesDelayed
    waiting for a configured delay
```

Important:

These values are intentionally **approximate** and can lag behind reality.

Do not use them when exact transactional accounting is required.

---

# SQS Receive / Delete Model

Receiving a message does NOT delete it.

```text
message available
      ↓
ReceiveMessage
      ↓
message becomes invisible
      ↓
consumer processes it
      ↓
DeleteMessage
      ↓
message permanently removed
```

If the consumer does not delete the message:

```text
visibility timeout expires
      ↓
message becomes available again
```

Our queue currently uses:

```text
VisibilityTimeout = 30 seconds
```

and:

```text
maxReceiveCount = 3
```

After enough unsuccessful receives, SQS can redrive the message to the configured DLQ.

---

# CloudWatch Logs

## Tail Lambda logs

```bash
aws logs tail \
  /aws/lambda/saas-platform-dev-upload-processor \
  --since 5m \
  --profile saas-learning
```

Lambda's default log-group convention is:

```text
/aws/lambda/<function-name>
```

Example:

```text
/aws/lambda/saas-platform-dev-upload-processor
```

## Discover log groups

```bash
aws logs describe-log-groups \
  --query 'logGroups[].logGroupName' \
  --output text \
  --profile saas-learning
```

Lambda logs commonly contain:

```text
INIT_START
START
application logs
END
REPORT
```

---

# CloudWatch SQS Metrics

These are useful for understanding message flow rather than only looking at current queue depth.

## Messages sent

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/SQS \
  --metric-name NumberOfMessagesSent \
  --dimensions Name=QueueName,Value=saas-platform-dev-jobs \
  --statistics Sum \
  --period 60 \
  --start-time "$(date -u -v-10M +%Y-%m-%dT%H:%M:%SZ)" \
  --end-time "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --region us-east-1 \
  --profile saas-learning
```

## Messages received

Same command with:

```bash
--metric-name NumberOfMessagesReceived
```

## Messages deleted

Same command with:

```bash
--metric-name NumberOfMessagesDeleted
```

Useful mental model:

```text
NumberOfMessagesSent
        ↓
       SQS
        ↓
NumberOfMessagesReceived
        ↓
    application
        ↓
NumberOfMessagesDeleted
```

Queue depth alone doesn't tell you whether messages are flowing successfully.

A healthy consumer may keep queue depth near zero even while processing lots of messages.

---

# ECS

## List ECS services

```bash
aws ecs list-services \
  --cluster saas-platform-dev \
  --profile saas-learning
```

## Inspect service state

```bash
aws ecs describe-services \
  --cluster saas-platform-dev \
  --services saas-platform-dev-app \
  --query 'services[0].{desired:desiredCount,running:runningCount,pending:pendingCount}' \
  --profile saas-learning
```

Example:

```json
{
  "desired": 1,
  "running": 1,
  "pending": 0
}
```

## List running tasks for a service

```bash
aws ecs list-tasks \
  --cluster saas-platform-dev \
  --service-name saas-platform-dev-app \
  --desired-status RUNNING \
  --profile saas-learning
```

## Temporarily stop a service

```bash
aws ecs update-service \
  --cluster saas-platform-dev \
  --service saas-platform-dev-app \
  --desired-count 0 \
  --profile saas-learning
```

## Start it again

```bash
aws ecs update-service \
  --cluster saas-platform-dev \
  --service saas-platform-dev-app \
  --desired-count 1 \
  --profile saas-learning
```

## Inspect the task definition used by a service

```bash
aws ecs describe-task-definition \
  --task-definition $(aws ecs describe-services \
    --cluster saas-platform-dev \
    --services saas-platform-dev-app \
    --query 'services[0].taskDefinition' \
    --output text \
    --profile saas-learning) \
  --query 'taskDefinition.containerDefinitions[].{name:name,image:image,environment:environment}' \
  --profile saas-learning
```

This is a useful composition:

```text
describe-services
        ↓
find taskDefinition ARN
        ↓
describe-task-definition
        ↓
inspect containers
```

---

# Lambda

## Find event-source mappings involving an SQS queue

```bash
aws lambda list-event-source-mappings \
  --profile saas-learning \
  --query 'EventSourceMappings[?contains(EventSourceArn, `saas-platform-dev-jobs`)].{UUID:UUID,Function:FunctionArn,State:State,Source:EventSourceArn}'
```

Useful for answering questions like:

```text
Is a Lambda consuming this SQS queue?
```

Remember there are two different directions:

```text
S3 → Lambda

configured with:
S3 notification
+
Lambda permission allowing S3 invocation
```

versus:

```text
SQS → Lambda

configured with:
Lambda event-source mapping
```

---

# CloudTrail

## Search recent events by API operation

```bash
aws cloudtrail lookup-events \
  --lookup-attributes \
    AttributeKey=EventName,AttributeValue=ReceiveMessage \
  --start-time "$(date -u -v-30M +%Y-%m-%dT%H:%M:%SZ)" \
  --end-time "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --max-results 50 \
  --profile saas-learning
```

Important:

CloudTrail does not automatically give you every possible data-plane operation.

Some services/actions require configuring appropriate CloudTrail data events ahead of time.

CloudTrail is generally useful for:

```text
Who did it?
What API did they call?
When did they do it?
From where?
```

---

# Secrets Manager

## Inspect secret metadata

```bash
aws secretsmanager describe-secret \
  --secret-id <secret-arn> \
  --profile saas-learning
```

Conceptual distinction:

```text
describe-secret
    metadata about the secret

get-secret-value
    actual secret contents
```

Be careful with:

```bash
aws secretsmanager get-secret-value
```

because the actual secret can end up in:

- terminal output
- shell history
- logs
- copied debugging output

---

# RDS / Aurora

## Describe Aurora/RDS clusters

```bash
aws rds describe-db-clusters \
  --profile saas-learning
```

Useful for discovering:

- endpoints
- engine/version
- cluster state
- members
- managed master-secret information
- networking configuration

---

# Network Connectivity

## Test whether a TCP port is reachable

```bash
nc -vz -w 3 HOSTNAME 5432
```

Example:

```bash
nc -vz -w 3 \
  saas-platform-dev.cluster-xxxxxxxx.us-east-1.rds.amazonaws.com \
  5432
```

This proves:

```text
TCP connection can be established
```

It does NOT prove:

```text
database credentials work
database queries work
application works
```

Think in layers:

```text
network connectivity
        ↓
protocol connection
        ↓
authentication
        ↓
application behavior
```

---

# Terraform

Assuming:

```bash
alias tf=terraform
```

## Initialize

```bash
tf init
```

Downloads/resolves providers and initializes the backend.

## Plan

```bash
tf plan
```

Compare:

```text
configuration
vs
Terraform state
vs
AWS reality
```

and determine what Terraform proposes changing.

## Apply

```bash
tf apply
```

## Destroy

```bash
tf destroy
```

Be careful. Obviously.

## List resources Terraform believes it owns

```bash
tf state list
```

## Inspect one Terraform resource

```bash
tf state show <resource-address>
```

Example:

```bash
tf state show aws_instance.tailscale_router
```

## Look specifically for drift

```bash
tf plan -refresh-only
```

Useful when asking:

```text
Has AWS reality changed outside Terraform?
```

## Deliberately replace a resource

```bash
tf apply \
  -replace="aws_instance.tailscale_router"
```

Useful for testing whether disposable/reproducible infrastructure actually is disposable/reproducible.

---

# Terraform Dependency Model

```text
required_providers
    ↓
declares provider source
and allowed version range

.terraform.lock.hcl
    ↓
locks exact selected versions
and checksums

terraform init
    ↓
resolves/downloads providers

.terraform/
    ↓
local downloaded provider binaries

terraform.tfstate
    ↓
infrastructure state
NOT dependency versions
```

Commit:

```text
.terraform.lock.hcl
```

Do not commit:

```text
.terraform/
```

---

# Useful Shell Helpers

## Current UTC time

```bash
date -u
```

## Ten minutes ago in ISO format — macOS

```bash
date -u -v-10M +%Y-%m-%dT%H:%M:%SZ
```

## Thirty minutes ago

```bash
date -u -v-30M +%Y-%m-%dT%H:%M:%SZ
```

These are useful for CloudWatch/CloudTrail queries.

---

# ISO 8601 Timestamps

Example:

```text
2026-10-01T18:09:00-05:00
```

Read as:

```text
2026-10-01
October 1, 2026

T
date/time separator

18:09:00
6:09 PM

-05:00
UTC offset — five hours behind UTC
```

Equivalent UTC timestamp:

```text
2026-10-01T23:09:00Z
```

`Z` means UTC / Zulu time.

---

# Environment Variables

## Set AWS profile for one command

```bash
AWS_PROFILE=saas-learning aws sts get-caller-identity
```

## Set AWS profile for the shell

```bash
export AWS_PROFILE=saas-learning
```

Our `.envrc`:

```bash
export PATH="$PWD/bin:$PATH"
export AWS_PROFILE=saas-learning
```

Then:

```bash
direnv allow
```

---

# Silent Input

Useful for temporary credentials, presigned URLs, etc.:

```bash
read -s VARIABLE
```

Example:

```bash
read -s PRESIGNED_URL
```

Use:

```bash
curl "$PRESIGNED_URL"
```

without dumping the URL back to the terminal.

---

# AWS CLI Querying

General AWS CLI grammar:

```text
aws <service> <operation> <arguments>
```

Examples:

```bash
aws sts get-caller-identity
aws ecs describe-services
aws sqs receive-message
aws s3api head-object
aws logs tail
aws cloudwatch get-metric-statistics
```

Three especially useful options:

```text
--profile
--query
--output
```

---

# `--query` / JMESPath

AWS commands often return giant JSON documents.

`--query` lets you extract only what you care about.

Instead of:

```bash
aws ecs describe-services \
  --cluster saas-platform-dev \
  --services saas-platform-dev-app
```

use:

```bash
aws ecs describe-services \
  --cluster saas-platform-dev \
  --services saas-platform-dev-app \
  --query 'services[0].{desired:desiredCount,running:runningCount,pending:pendingCount}'
```

Instead of giant JSON:

```json
{
  "desired": 1,
  "running": 1,
  "pending": 0
}
```

Learning basic JMESPath is extremely useful for AWS CLI work.

---

# AWS Debugging Mental Model

When something doesn't work, isolate boundaries instead of debugging the entire architecture at once.

For our upload pipeline:

```text
Laptop
   │
   │ presigned PUT
   ▼
S3
   │
   │ ObjectCreated
   ▼
Lambda
   │
   │ SendMessage
   ▼
SQS
   │
   │ ReceiveMessage
   ▼
ECS
   │
   │ DeleteMessage
   ▼
done
```

Prove each boundary independently.

Examples:

```text
curl returned 200
    → S3 PUT worked

object exists
    → S3 persisted it

Lambda START/END logs exist
    → S3 invoked Lambda

Lambda logged MessageId
    → SQS accepted SendMessage

queue depth increased
    → message persisted

NumberOfMessagesReceived increased
    → consumer received it

NumberOfMessagesDeleted increased
    → consumer acknowledged/deleted it
```

Do not infer the entire system works from one successful boundary.

---

# Terraform Debugging Mental Model

Always remember there are three things:

```text
Terraform configuration
        ↓
what SHOULD exist


Terraform state
        ↓
what Terraform THINKS it owns


AWS
        ↓
what ACTUALLY exists
```

They can disagree.

Useful tools:

```bash
tf plan
tf plan -refresh-only
tf state list
tf state show
```

And AWS CLI:

```bash
aws <service> describe-...
aws <service> list-...
```

A clean Terraform plan means:

```text
Terraform sees no changes needed
for the resources it manages
```

It does NOT mean:

```text
the entire AWS account exactly matches
the architecture represented by Terraform
```

Unmanaged resources can exist outside Terraform.

---

# Useful First Commands in an Unfamiliar AWS Account

```bash
aws sts get-caller-identity
```

```bash
aws configure get region
```

Then start discovering:

```bash
aws ecs list-clusters
aws ecs list-services --cluster <cluster>
aws rds describe-db-clusters
aws lambda list-functions
aws sqs list-queues
aws s3api list-buckets
aws logs describe-log-groups
```

Questions to answer:

```text
Who am I?

What account am I in?

What region am I using?

What workloads are running?

Where is state stored?

What networks exist?

What databases exist?

What queues/events exist?

What IAM roles do workloads use?

What is public?

What is private?

What does Terraform actually own?

What changed recently?
```

---

# Commands Worth Having in Muscle Memory

```bash
aws sso login --profile saas-learning
```

```bash
aws sts get-caller-identity --profile saas-learning
```

```bash
aws <service> list-...
```

```bash
aws <service> describe-...
```

```bash
aws logs tail <log-group> --since 5m
```

```bash
aws sqs get-queue-attributes ...
```

```bash
aws ecs describe-services ...
```

```bash
tf plan
```

```bash
tf plan -refresh-only
```

```bash
tf state list
```

```bash
tf state show <resource>
```

```bash
nc -vz -w 3 HOST PORT
```

The goal isn't memorizing every AWS CLI command.

The useful skill is being able to think:

```text
What AWS service owns this thing?

What operation do I need?

list?
describe?
get?
send?
receive?

What exact boundary am I trying to prove?
```

Then:

```text
aws <service> <operation>
```

and use `--query` to turn the resulting JSON firehose into something useful.
