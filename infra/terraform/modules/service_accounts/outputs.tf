output "service_account_emails" {
  value = {
    for key, sa in google_service_account.this : key => sa.email
  }
}

output "service_account_ids" {
  value = {
    for key, sa in google_service_account.this : key => sa.name
  }
}
