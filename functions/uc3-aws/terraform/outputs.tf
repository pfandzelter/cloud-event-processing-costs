output "uc3_aggregate_http_trigger" {
  # Access the module output with module.<module_name>.<output_name>
  value = module.uc3_aggregate_function.url
}
