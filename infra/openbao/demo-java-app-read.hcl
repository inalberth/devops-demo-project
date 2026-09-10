path "secret/data/demo-java-app/dev/*" {
  capabilities = ["read"]
}

path "secret/metadata/demo-java-app/dev/*" {
  capabilities = ["read", "list"]
}
