# terraform/variables.tf

variable "project" {
  default = "cloud-event-processing-costs"
}

variable "region" {
  default = "europe-west3" # Choose a region
}

variable "zone" {
  default = "b" # Choose a zone
}

variable "function_runtime" {
  default = "java11"
}

variable "function_entry_point" {
  default = "uc1.Store"
}

variable "use_pubsub" {
  type    = bool
  default = false
}

variable "load_instance_count" {
  default = "1"
  type    = number
}

variable "load_instance_type" {
  default = "e2-highcpu-4"
}

variable "num_sensors" {
  default = "1"
  type    = number
}

variable "function_memory" {
  default = 256
  type    = number
}

variable "run_name" {
  description = "Label to track Costs. Must be unique per run."

  validation {
    condition     = can(regex("^[a-zA-Z0-9-_]+$", var.run_name))
    error_message = "Can contain only lowercase letters, numeric characters, underscores, and dashes."
  }
}
