ui = true

disable_mlock = true

storage "raft" {
  path    = "/openbao/data"
  node_id = "openbao-1"
}

listener "tcp" {
  address         = "0.0.0.0:8200"
  cluster_address = "0.0.0.0:8201"

  tls_disable = true
}

api_addr     = "http://host.docker.internal:8200"
cluster_addr = "http://openbao:8201"
