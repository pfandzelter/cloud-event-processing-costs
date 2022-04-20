output "url" {
  # Access the module output with module.<module_name>.<output_name>
  value = google_cloudfunctions_function.function.https_trigger_url
}
