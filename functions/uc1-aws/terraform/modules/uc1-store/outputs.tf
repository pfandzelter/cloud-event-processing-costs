output "url" {
  # Access the module output with module.<module_name>.<output_name>
  value = var.use_pubsub ? "none" : "${aws_apigatewayv2_stage.lambda.invoke_url}/"
}
