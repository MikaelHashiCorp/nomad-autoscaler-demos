# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

variable "nomad_addr" {
  description = "The Nomad API HTTP address."
  type        = string
}

variable "skip_nomad_wait" {
  description = "If true, skip waiting for Nomad API readiness (used for Windows bootstrap debugging)."
  type        = bool
  default     = false
}
