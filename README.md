# Event-Driven Automation Pipeline (IaC)

A Terraform-managed configuration that deploys an asynchronous, event-driven data pipeline triggered by object storage lifecycle events.

---

## Architectural Overview

This solution removes the need for persistent compute polling by executing runtime code immediately when objects are created in storage.

* **Source S3 Bucket:** Handles raw file ingestion.
* **Destination S3 Bucket:** Stores processed output files to maintain structural data segregation.
* **AWS Lambda:** Executes processing logic statelessly on-demand without requiring server management.
* **S3 Event Notifications:** Triggers the Lambda function whenever a new object is created (`s3:ObjectCreated:*`) in the source bucket.

---

## Tech Stack

* **Storage Tier:** Amazon S3
* **Compute Tier:** AWS Lambda (`Python 3.11`)
* **Automation Trigger:** Amazon S3 Event Notifications
* **IaC Tooling:** Terraform `v1.5+`

---

## Prerequisites

Before deploying, ensure you have the following prerequisites configured on your local machine:

1. **AWS CLI:** Configured with appropriate programmatic access permissions.
2. **Terraform CLI:** Version `v1.5+` installed locally.

---

## Deployment Instructions

Follow these sequential steps to initialize, preview, and deploy the event-driven infrastructure.

### 1. Initialize Working Directory
Prepare the directory and download required cloud providers:
```bash
terraform init
```

### 2. Preview Infrastructure Plan
Generate and review the infrastructure execution plan to verify changes:
```bash
terraform plan
```

### 3. Apply Configuration
Provision the active architecture components directly to your AWS account:
```bash
terraform apply --auto-approve
```

### 4. Resource Teardown
Destroy the active components when testing is complete to prevent unexpected state clutter:
```bash
terraform destroy --auto-approve
```

---

## Architectural Guardrails

* **Infinite Loop Prevention:** If a serverless function processes files and writes them back into the same bucket that triggers its execution, it creates an infinite recursive loop. This results in exponential, unintended cost spikes.
* **Dual-Bucket Pattern:** This architecture structurally eliminates the infinite execution risk by strictly decoupling ingestion and storage. The Lambda function reads exclusively from the source bucket and writes finished files strictly into the destination bucket.
