provider "google" {
  project = var.project
  region  = var.region
}

locals {
  # choose code directory based on runtime
  # go -> uc3-go
  # java -> uc3-aggregate
  # node -> uc3-node
  code_dir = length(regexall("go*", var.function_runtime)) > 0 ? "uc3-go" : length(regexall("nodejs*", var.function_runtime)) > 0 ? "uc3-node" : "uc3-aggregate"
}

module "uc3_pubsub" {
  source     = "./modules/uc3-pubsub"
  project    = var.project
  region     = var.region
  topic_name = "uc3-pubsub"
  deploy     = var.use_pubsub
  run_name   = var.run_name
}

module "uc3_aggregate_function" {
  source               = "./modules/uc3-aggregate"
  project              = var.project
  region               = var.region
  function_name        = "uc3-aggregate"
  code_dir             = local.code_dir
  function_entry_point = var.function_entry_point
  function_runtime     = var.function_runtime
  window_size          = var.aggregate_window_size
  interval             = var.aggregate_interval
  select_collection    = var.select_collection
  run_name             = var.run_name
  function_memory      = var.function_memory
  use_pubsub           = var.use_pubsub
  pubsub_topic         = var.use_pubsub ? module.uc3_pubsub.topic : "none"
}

module "uc3_load_instance" {
  source         = "./modules/uc3-load"
  project        = var.project
  region         = var.region
  zone           = "${var.region}-${var.zone}"
  instance_name  = "uc3-load-${var.run_name}"
  instance_type  = var.load_instance_type
  instance_count = var.load_instance_count
  run_name       = var.run_name
  num_sensors    = var.num_sensors
  function_url   = var.use_pubsub ? "none" : module.uc3_aggregate_function.url
  use_pubsub     = var.use_pubsub
  pubsub_topic   = var.use_pubsub ? module.uc3_pubsub.topic : "none"

}
