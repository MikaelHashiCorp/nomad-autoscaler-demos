scaling "azure_cluster_policy" {
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
