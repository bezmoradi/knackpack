#!/bin/bash
# A Terraform root, infra/storage/, that creates one S3 bucket per name in a
# list with for_each, applied to production with Terraform 1.11. The
# uncommitted change retires the exports bucket by removing its name from the
# middle of the list. for_each addresses each bucket by its name, so the plan
# destroys only the exports bucket, which is the intended retirement.
set -euo pipefail
git init -q
git config user.name "Eval Fixture"
git config user.email "fixture@example.com"
mkdir -p infra/storage

cat > README.md <<'MD'
# shop storage

Terraform for the shop's S3 buckets lives in `infra/storage/`, one bucket per
name in `bucket_names`. Production applies with Terraform 1.11 from the deploy
pipeline:

    terraform -chdir=infra/storage init -input=false
    terraform -chdir=infra/storage apply -input=false -var-file=prod.tfvars

The `shop-audit-logs` bucket holds the audit records of every payment and
refund. They must be kept for seven years, so that bucket must never be
deleted or recreated.
MD

cat > CHANGELOG.md <<'MD'
# Changelog

## 2026-09-14

- Add the `shop-audit-logs` bucket.
MD

cat > infra/storage/versions.tf <<'HCL'
terraform {
  required_version = "~> 1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket       = "shop-terraform-state"
    key          = "storage/terraform.tfstate"
    region       = "eu-west-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = "eu-west-1"
}
HCL

cat > infra/storage/variables.tf <<'HCL'
variable "bucket_names" {
  description = "Names of the S3 buckets to create, one bucket per name."
  type        = list(string)
}
HCL

cat > infra/storage/main.tf <<'HCL'
resource "aws_s3_bucket" "data" {
  for_each = toset(var.bucket_names)

  bucket = each.key
}
HCL

cat > infra/storage/prod.tfvars <<'HCL'
bucket_names = ["shop-invoices", "shop-exports", "shop-audit-logs"]
HCL

git add -A
git commit -qm "Production buckets"

cat > infra/storage/prod.tfvars <<'HCL'
bucket_names = ["shop-invoices", "shop-audit-logs"]
HCL

cat > CHANGELOG.md <<'MD'
# Changelog

## Unreleased

- Retire the `shop-exports` bucket. The export job moved to the warehouse in
  October, and the bucket is empty.

## 2026-09-14

- Add the `shop-audit-logs` bucket.
MD
