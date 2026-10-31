#!/bin/bash
# A Terraform root, infra/reports/, that manages two S3 buckets and is applied
# by CI with Terraform 1.11 on every push to main. The uncommitted change hands
# the legacy reports bucket over to another team's stack: it deletes the
# bucket's resource blocks and adds removed blocks with no lifecycle block,
# which under Terraform destroy the bucket instead of only forgetting it.
set -euo pipefail
git init -q
git config user.name "Eval Fixture"
git config user.email "fixture@example.com"
mkdir -p infra/reports .github/workflows

cat > README.md <<'MD'
# shop infrastructure

Terraform for the shop's report storage in AWS lives in `infra/reports/`.

Production applies with Terraform 1.11 in CI (`.github/workflows/infra.yml`).
A pull request that touches `infra/reports/` runs `terraform plan`, and a push
to main runs `terraform apply` with the plan it just made. Nobody applies from
a laptop.

State is kept in the `shop-terraform-state` bucket and locked with a lock file
next to it.
MD

cat > .github/workflows/infra.yml <<'YAML'
name: infra

on:
  pull_request:
    paths:
      - "infra/reports/**"
  push:
    branches: [main]
    paths:
      - "infra/reports/**"

permissions:
  contents: read
  id-token: write

concurrency:
  group: infra-reports
  cancel-in-progress: false

jobs:
  terraform:
    runs-on: ubuntu-latest
    environment: production
    defaults:
      run:
        working-directory: infra/reports
    steps:
      - uses: actions/checkout@v4
        with:
          persist-credentials: false
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/reports-terraform
          aws-region: eu-west-1
      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.11.4
          terraform_wrapper: false
      - run: terraform init -input=false
      - run: terraform plan -input=false -out=tfplan
      - if: github.event_name == 'push' && github.ref == 'refs/heads/main'
        run: terraform apply -input=false tfplan
YAML

cat > infra/reports/versions.tf <<'HCL'
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
    key          = "reports/terraform.tfstate"
    region       = "eu-west-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = "eu-west-1"

  default_tags {
    tags = {
      stack = "reports"
    }
  }
}
HCL

cat > infra/reports/main.tf <<'HCL'
# Monthly sales reports, written by the reporting job.
resource "aws_s3_bucket" "reports" {
  bucket = "shop-reports"
}

resource "aws_s3_bucket_versioning" "reports" {
  bucket = aws_s3_bucket.reports.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Reports from before the reporting job was rewritten, kept for reference.
resource "aws_s3_bucket" "legacy_reports" {
  bucket        = "shop-legacy-reports"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "legacy_reports" {
  bucket = aws_s3_bucket.legacy_reports.id

  versioning_configuration {
    status = "Enabled"
  }
}
HCL

git add -A
git commit -qm "Report buckets, applied from CI"

cat > infra/reports/main.tf <<'HCL'
# Monthly sales reports, written by the reporting job.
resource "aws_s3_bucket" "reports" {
  bucket = "shop-reports"
}

resource "aws_s3_bucket_versioning" "reports" {
  bucket = aws_s3_bucket.reports.id

  versioning_configuration {
    status = "Enabled"
  }
}

# The legacy reports bucket is being handed over to the data team, whose own
# stack imports it. Stop managing it here, but keep the bucket and every
# report in it: the data team still needs that data.
removed {
  from = aws_s3_bucket.legacy_reports
}

removed {
  from = aws_s3_bucket_versioning.legacy_reports
}
HCL
