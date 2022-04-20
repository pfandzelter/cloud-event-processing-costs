data "aws_ami" "ecs-ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn-ami*amazon-ecs-optimized"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["591542846629"] # AWS

}

resource "aws_instance" "uc1load" {
  ami           = data.aws_ami.ecs-ami.id
  instance_type = var.instance_type

  user_data = <<-EOF
    #!/bin/bash
    sleep 30
    docker run -d -e NUM_SENSORS="${var.num_sensors}" -e THREADS="8" -e TARGET="${var.use_pubsub ? "pubsub" : "http"}" -e HTTP_URL="${var.use_pubsub ? "none" : var.function_url}" -e HTTP_TIMEOUT_MS="60000" -e PUBSUB_INPUT_TOPIC="${var.use_pubsub ? var.pubsub_topic : "none"}" -e PUBSUB_PROJECT="${var.use_pubsub ? var.project : "none"}" ghcr.io/cau-se/theodolite-uc1-workload-generator
  EOF

  tags = {
    Run = var.run_name
  }
}
