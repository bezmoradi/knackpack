#!/bin/bash
# A Terraform configuration with two S3 buckets and no tags. The user asks for
# a cost-center tag on both, a change to make, not a Terraform review.
set -euo pipefail
git init -q -b main
git config user.name "Kofi Mensah"
git config user.email "kofi@example.com"
cat > versions.tf <<'TF'
terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "eu-west-1"
}
TF
cat > main.tf <<'TF'
resource "aws_s3_bucket" "receipts" {
  bucket = "acme-payments-receipts"
}

resource "aws_s3_bucket" "exports" {
  bucket = "acme-payments-exports"
}

resource "aws_s3_bucket_public_access_block" "receipts" {
  bucket                  = aws_s3_bucket.receipts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
TF
git add -A
git commit -qm "Payments buckets"
