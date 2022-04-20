locals {
  timestamp = formatdate("YYMMDDhhmmss", timestamp())
  root_dir  = abspath("../${var.code_dir}")
}

# Compress source code
data "archive_file" "source" {
  type        = "zip"
  source_dir  = local.root_dir
  output_path = "/tmp/${var.function_name}-${local.timestamp}-${var.run_name}.zip"
}

# Create bucket that will host the source code
resource "google_storage_bucket" "bucket" {
  name     = "${var.project}-${var.function_name}-${var.run_name}"
  location = upper(var.region)
  labels = {
    run = var.run_name
  }
}

# Add source code zip to bucket
resource "google_storage_bucket_object" "zip" {
  # Append file MD5 to force bucket to be recreated
  name   = "source.zip#${data.archive_file.source.output_md5}"
  bucket = google_storage_bucket.bucket.name
  source = data.archive_file.source.output_path
}

# Enable Cloud Functions API
resource "google_project_service" "cf" {
  project = var.project
  service = "cloudfunctions.googleapis.com"

  disable_dependent_services = true
  disable_on_destroy         = false
}

# Enable Cloud Build API
resource "google_project_service" "cb" {
  project = var.project
  service = "cloudbuild.googleapis.com"

  disable_dependent_services = true
  disable_on_destroy         = false
}

# Create Cloud Function
resource "google_cloudfunctions_function" "function" {
  name    = "${var.function_name}-${var.run_name}"
  runtime = var.function_runtime # Switch to a different runtime if needed

  available_memory_mb   = var.function_memory
  source_archive_bucket = google_storage_bucket.bucket.name
  source_archive_object = google_storage_bucket_object.zip.name
  entry_point           = var.function_entry_point
  environment_variables = {
    "GOOGLE_CLOUD_PROJECT" = var.project,
    "SELECT_COLLECTION"    = "${var.select_collection}-${var.run_name}",
    "WINDOW_SIZE"          = var.window_size,
    "INTERVAL"             = var.interval,
  }

  trigger_http = var.use_pubsub ? null : true

  dynamic "event_trigger" {
    for_each = var.use_pubsub ? [1] : []

    content {
      event_type = "google.pubsub.topic.publish"
      resource   = var.pubsub_topic
    }
  }

  labels = {
    run = var.run_name
  }
}

# Create IAM entry so all users can invoke the function
resource "google_cloudfunctions_function_iam_member" "invoker" {
  project        = google_cloudfunctions_function.function.project
  region         = google_cloudfunctions_function.function.region
  cloud_function = google_cloudfunctions_function.function.name

  role   = "roles/cloudfunctions.invoker"
  member = "allUsers"
}
