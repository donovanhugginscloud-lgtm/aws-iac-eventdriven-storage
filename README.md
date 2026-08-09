# Event-Driven Automation Pipeline (IaC)

A Terraform-managed configuration that deploys an asynchronous, event-driven data pipeline triggered by object storage lifecycle events.

## Architectural Overview
This solution removes the need for persistent compute polling by executing runtime code immediately when objects are created in storage.
* Source S3 Bucket: Handles raw file ingestion.
* Destination S3 Bucket: Stores processed output files to maintain structural data segregation.
* AWS Lambda: Executes processing logic statelessly on-demand without requiring server management.
* S3 Event Notifications: Triggers the Lambda function whenever a new object is created (`s3:ObjectCreated:*`) in the source bucket.

## Tech Stack
* Storage Tier: Amazon S3
* Compute Tier: AWS Lambda (Python 3.11)
* Automation Trigger: Amazon S3 Event Notifications
* IaC Tooling: Terraform v1.5+

## Prerequisites
* AWS CLI configured with appropriate programmatic access permissions
* Terraform CLI (v1.5+) installed locally

## Deployment Instructions
1. Initialize the project workspace:
   ```bash
   terraform init
   ```
2. Generate and review the infrastructure deployment plan:
   ```bash
   terraform plan
   ```
3. Provision the resources on AWS:
   ```bash
   terraform apply --auto-approve
   ```
4. Destroy the infrastructure when testing is complete:
   ```bash
   terraform destroy --auto-approve
   ```

## Architectural Guardrails
* Infinite Loop Prevention: If a serverless function processes files and writes them back into the same bucket that triggers its execution, it creates an infinite recursive loop. This results in exponential, unintended cost spikes.
* Dual-Bucket Pattern: This architecture structurally eliminates the infinite execution risk by strictly decoupling ingestion and storage. The Lambda function reads exclusively from the source bucket and writes finished files strictly into the destination bucket.
