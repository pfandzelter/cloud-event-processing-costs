# terraform/variables.tf

variable "project" {
  default = "cloud-event-processing-costs"
}

variable "region" {
  default = "eu-central-1" # Choose a region
}

variable "zone" {
  default = "a" # Choose a zone
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
  default = "m5.xlarge"
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
