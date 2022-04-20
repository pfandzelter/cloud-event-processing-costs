provider "aws" {
  region = var.region
}

module "uc1_pubsub" {
  source     = "./modules/uc1-pubsub"
  project    = var.project
  region     = var.region
  topic_name = "uc1-pubsub"
  deploy     = var.use_pubsub
  run_name   = var.run_name
}

module "uc1_store_function" {
  source               = "./modules/uc1-store"
  region               = var.region
  function_name        = "uc1-store"
  function_entry_point = "uc1.Store"
  run_name             = var.run_name
  function_memory      = var.function_memory
  use_pubsub           = var.use_pubsub
  pubsub_topic         = var.use_pubsub ? module.uc1_pubsub.topic : "none"
}

module "uc1_load_instance" {
  source         = "./modules/uc1-load"
  project        = var.project
  region         = var.region
  zone           = "${var.region}-${var.zone}"
  instance_name  = "uc1-load-${var.run_name}"
  instance_type  = var.load_instance_type
  instance_count = var.load_instance_count
  run_name       = var.run_name
  num_sensors    = var.num_sensors
  function_url   = var.use_pubsub ? "none" : module.uc1_store_function.url
  use_pubsub     = var.use_pubsub
  pubsub_topic   = var.use_pubsub ? module.uc1_pubsub.topic : "none"
}
