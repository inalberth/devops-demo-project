path "secret/data/payroll/dev/*" {
  capabilities = ["read"]
}

path "secret/metadata/payroll/dev/*" {
  capabilities = ["read", "list"]
}