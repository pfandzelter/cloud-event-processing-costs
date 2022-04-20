resource "google_pubsub_topic" "topic" {
  name = "${var.topic_name}-${var.run_name}"
  # deploy this topic only when pubsub is used
  count = var.deploy ? 1 : 0

  message_storage_policy {
    allowed_persistence_regions = [
      var.region,
    ]
  }
}
