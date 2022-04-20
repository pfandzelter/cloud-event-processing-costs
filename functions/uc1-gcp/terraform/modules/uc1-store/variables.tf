variable "project" {
  type = string
}
variable "region" {
  type = string
}

variable "code_dir" {
  type = string
}

variable "function_name" {
  type = string
}

variable "function_runtime" {
  type = string
}

variable "function_entry_point" {
  type = string
}

variable "function_memory" {
  type = number
}

variable "use_pubsub" {
  type = bool
}

variable "pubsub_topic" {
  type = string
}

variable "run_name" {
  description = "Label to track Costs. Must be unique per run."
}
