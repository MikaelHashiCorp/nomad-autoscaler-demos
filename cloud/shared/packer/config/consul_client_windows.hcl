# Windows Consul Client Configuration
advertise_addr   = "IP_ADDRESS"
bind_addr        = "0.0.0.0"
client_addr      = "0.0.0.0"
server           = false
ui               = true
data_dir         = "C:\\opt\\consul\\data"
log_level        = "TRACE"
log_file         = "C:\\opt\\consul\\logs\\"
log_rotate_duration  = "1h"
log_rotate_max_files = 3
retry_join           = ["RETRY_JOIN"]

service {
  name = "consul-client"
}
