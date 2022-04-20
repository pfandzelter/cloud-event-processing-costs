data "google_compute_image" "cos_image" {
  family  = "cos-stable"
  project = "cos-cloud"
}

resource "google_compute_instance" "default" {
  name         = "${var.instance_name}-${count.index}"
  machine_type = var.instance_type
  zone         = var.zone
  count        = var.instance_count

  boot_disk {
    initialize_params {
      image = data.google_compute_image.cos_image.self_link
    }
  }

  network_interface {
    network = "default"

    access_config {
      // Ephemeral public IP
    }
  }
  metadata = {
    gce-container-declaration = <<EOT
spec:
  containers:
    - image: ghcr.io/cau-se/theodolite-uc1-workload-generator
      name: uc1-load
      securityContext:
        privileged: false
      stdin: false
      tty: false
      volumeMounts: []
      restartPolicy: Always
      volumes: []
      env:
        - name: NUM_SENSORS
          value: "${var.num_sensors}"
        - name: BOOTSTRAP_SERVER
          value: "${var.instance_name}-0:5701"
        - name: THREADS
          value: "8"
        - name: TARGET
          value: "${var.use_pubsub ? "pubsub" : "http"}"
        - name: HTTP_URL
          value: "${var.use_pubsub ? "none" : var.function_url}"
        - name: HTTP_TIMEOUT_MS
          value: "10000"
        - name: PUBSUB_INPUT_TOPIC
          value: "${var.use_pubsub ? var.pubsub_topic : "none"}"
        - name: PUBSUB_PROJECT
          value: "${var.use_pubsub ? var.project : "none"}"

EOT
  }
  # metadata_startup_script = "docker run --rm -it -e TARGET=http -e HTTP_URL=\"${var.function_url}\" -e NUM_SENSORS=\"${var.num_sensors}\" -e BOOTSTRAP_SERVER=\"${var.bootstrap_server}\" -e THREADS=\"8\" ghcr.io/cau-se/theodolite-uc1-workload-generator"

  labels = {
    run = var.run_name
  }

  service_account {
    scopes = ["cloud-platform"]
  }
}
