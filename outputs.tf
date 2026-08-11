output "source_bucket_name" {
  value       = aws_s3_bucket.source.id
  description = "The globally unique name of the raw data ingestion bucket"
}

output "destination_bucket_name" {
  value       = aws_s3_bucket.destination.id
  description = "The globally unique name of the processed output bucket"
}
