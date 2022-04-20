#!/usr/bin/python3

import subprocess
import os
import time
import math
import uuid

import yaspin

import collect_pricing_aws
import config

# change this on your machine
TERRAFORM_BIN = config.TERRAFORM_BIN
GCLOUD_CREDS = config.GCLOUD_CREDS

AWS_REGION = config.AWS_REGION
AWS_CREDS = config.AWS_CREDS
AWS_CONFIG = config.AWS_CONFIG

CURR_DIR = os.getcwd()

def run_experiment(num_sensors: int, use_case: str, function: str, sleep_seconds: int, sensors_per_instance: int, pubsub: bool) -> None:
    print(f"Running experiment with {num_sensors} sensors")

    access_method = "pubsub" if pubsub else "http"

    # function_memory = "256"
    # function_type = "256MB-0.1667vCPU"

    # create a unique experiment id
    experiment_id = str(uuid.uuid4()).split("-")[0]
    run_name = f"{num_sensors}-{access_method}-{experiment_id}"
    function_name = f"{function}-{run_name}"

    print(f"Experiment name: {run_name}")

    # figure out how many machines we need
    num_machines = math.ceil(num_sensors / sensors_per_instance)
    print(f"{num_machines} machine(s) needed")

    # figure out how many sensors to put on each machine
    num_sensors_per_machine = math.ceil(num_sensors / num_machines)
    print(f"{num_sensors_per_machine} sensors per machine")

    # create a new directory for this experiment
    use_case_dir = os.path.join(CURR_DIR, use_case, "terraform")
    print(f"Use case directory: {use_case_dir}")

    # terraform init
    with yaspin.yaspin(text="terraform init") as sp:
        terraform_vars = {
            "TF_VAR_region": AWS_REGION,
            "TF_VAR_num_sensors": str(num_sensors_per_machine),
            "TF_VAR_run_name": run_name,
            "TF_VAR_load_instance_count": str(num_machines),
            "TF_VAR_use_pubsub": str(pubsub).lower(),
            "GOOGLE_APPLICATION_CREDENTIALS": GCLOUD_CREDS,
            "AWS_SHARED_CREDENTIALS_FILE": AWS_CREDS,
            "AWS_CONFIG_FILE": AWS_CONFIG,
        }

        subprocess.run([TERRAFORM_BIN, "init"], cwd=use_case_dir, env=terraform_vars, stdout=subprocess.DEVNULL, check=True)
        sp.green.ok("✔")

    try:

        sp = yaspin.kbi_safe_yaspin(text="terraform apply", timer=True)
        sp.start()
        # terraform apply
        subprocess.run([TERRAFORM_BIN, "apply", "-auto-approve"], cwd=use_case_dir, env=terraform_vars, stdout=subprocess.DEVNULL, check=True)
        sp.green.ok("✔")
        sp.stop()

        # sleep for a while
        with yaspin.yaspin(text=f"Experiment running for {sleep_seconds} seconds", timer=True) as sp:
            time.sleep(sleep_seconds)

    except subprocess.CalledProcessError as e:
        sp.write(f"Terraform failed with error code {e.returncode}")
        sp.write(e.output)
        sp.red.fail("✘")
        sp.stop()

    finally:
        # terraform destroy
        with yaspin.yaspin(text="terraform destroy") as sp:
            subprocess.run([TERRAFORM_BIN, "destroy", "-auto-approve"], cwd=use_case_dir, env=terraform_vars, stdout=subprocess.DEVNULL, check=True)
            sp.green.ok("✔")

    # collect results
    # this could be optimized by starting it in another process/thread
    collect_pricing_aws.collect(function_name)

if __name__ == "__main__":

    use_cases = [{
        "use_case": "uc1-aws",
        "function": "uc1-store",
    },{
        "use_case": "uc3-aws",
        "function": "uc3-aggregate",
    }]

    NUM_SENSORS = 1
    SLEEP_SECONDS = 240
    SENSORS_PER_INSTANCE = 5000

    for use_case in use_cases:
        for pubsub in [ False ]:
            run_experiment(num_sensors=NUM_SENSORS, use_case=use_case["use_case"], function=use_case["function"], sleep_seconds=SLEEP_SECONDS, sensors_per_instance=SENSORS_PER_INSTANCE, pubsub=pubsub)
