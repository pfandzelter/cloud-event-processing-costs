output "uc1_store_http_trigger" {
  # Access the module output with module.<module_name>.<output_name>
  value = module.uc1_store_function.url
}
