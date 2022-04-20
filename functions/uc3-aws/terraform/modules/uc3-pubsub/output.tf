output "topic" {
  value = var.deploy ? google_pubsub_topic.topic[0].name : "none"
}
