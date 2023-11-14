job "azure-autoscaler" {
  datacenters = ["dc2"]

  group "autoscaler" {
    count = 1

    network {
      port "http" {}
    }

    task "autoscaler" {
      driver = "docker"

      config {
        image   = "hashicorp/nomad-autoscaler:0.3.7"
        command = "nomad-autoscaler"

        args = [
          "agent",
          "-config",
          "${NOMAD_TASK_DIR}/config.hcl",
          "-http-bind-address",
          "0.0.0.0",
          "-http-bind-port",
          "${NOMAD_PORT_http}",
          "-policy-dir",
          "${NOMAD_TASK_DIR}/policies/",
          "-log-level",
          "TRACE",
          "-enable-debug",
        ]

        ports = ["http"]
      }

      template {
        data = <<EOF
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
EOF

        destination = "${NOMAD_TASK_DIR}/config.hcl"
      }

      template {
        data = <<EOF
scaling "cluster_policy" {
  enabled = true
  min     = 1
  max     = 2

  policy {

    cooldown            = "2m"
    evaluation_interval = "1m"

    check "cpu_allocated_percentage" {
      source = "prometheus"
      query  = "sum(nomad_client_allocated_cpu{node_class=\"hashistack\"}*100/(nomad_client_unallocated_cpu{node_class=\"hashistack\"}+nomad_client_allocated_cpu{node_class=\"hashistack\"}))/count(nomad_client_allocated_cpu{node_class=\"hashistack\"})"

      strategy "target-value" {
        target = 70
      }
    }

    check "mem_allocated_percentage" {
      source = "prometheus"
      query  = "sum(nomad_client_allocated_memory{node_class=\"hashistack\"}*100/(nomad_client_unallocated_memory{node_class=\"hashistack\"}+nomad_client_allocated_memory{node_class=\"hashistack\"}))/count(nomad_client_allocated_memory{node_class=\"hashistack\"})"

      strategy "target-value" {
        target = 70
      }
    }

    target "azure-vmss" {
      resource_group      = "hcs-autosc-main-mws-immense-corgi"
      vm_scale_set        = "clients"
      node_class          = "hashistack"
      node_drain_deadline = "5m"
    }
  }
}
EOF

        destination = "${NOMAD_TASK_DIR}/policies/hashistack.hcl"
      }

      resources {
        cpu    = 50
        memory = 128
      }

      service {
        name = "autoscaler"
        port = "http"

        check {
          type     = "http"
          path     = "/v1/health"
          interval = "5s"
          timeout  = "2s"
        }
      }
    }
  }
}

