# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

variable "nomad_addr" {
  description = "The Nomad API HTTP address."
  type        = string
}

variable "wait_timeout_seconds" {
  description = "Maximum seconds to wait for Nomad API readiness before failing."
  type        = number
  default     = 600
}
