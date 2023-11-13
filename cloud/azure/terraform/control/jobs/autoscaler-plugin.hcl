nomad {
  address = "http://{{env "attr.unique.network.ip-address" }}:4646"
}

apm "prometheus" {
  driver = "prometheus"
  config = {
    address = "http://{{ range service "prometheus" }}{{ .Address }}:{{ .Port }}{{ end }}"
  }
}

target "azure-vmss" {
  driver = "azure-vmss"
  config = {
    subscription_id = "6e3c9dc4-6f76-4d10-904c-0f016dcad60d"
  }
}

strategy "target-value" {
  driver = "target-value"
}