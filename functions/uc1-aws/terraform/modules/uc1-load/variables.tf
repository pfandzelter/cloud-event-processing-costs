variable "project" {}

variable "region" {}

variable "zone" {}

variable "instance_count" {}

variable "instance_type" {}

variable "instance_name" {}

variable "function_url" {}

variable "num_sensors" {}

variable "use_pubsub" {
  type = bool
}

variable "pubsub_topic" {}

variable "run_name" {
  description = "Label to track Costs. Must be unique per run."
}
