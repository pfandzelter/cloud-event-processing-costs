# Functions Implementations

Our FaaS benchmark implementations include UC1 and UC3 use-cases for:

- Java on Google Cloud Functions with HTTP triggers
- Node.js on Google Cloud Functions with HTTP triggers
- Go on Google Cloud Functions with HTTP triggers
- Java on Google Cloud Functions with Pub/Sub triggers
- Java on AWS Lambda with HTTP triggers

## Prerequisites

The following tools are required to build and run all benchmarks:

- [Terraform 1.X](https://www.terraform.io/)
- [Google Cloud SDK 376.0.0](https://cloud.google.com/sdk/)
- [AWS CLI 2.4.15](https://aws.amazon.com/cli/)
- [Python 3.9](https://www.python.org/) with [`pip` 22.0.3](https://pypi.org/project/pip/)
- [Node.js v17.8.0](https://nodejs.org/en/)
- [OpenJDK 17.0.2](http://openjdk.java.net/)
- [Gradle 7.4.1](https://gradle.org/)
- [GNU Make 3.8.1](https://www.gnu.org/software/make/)

Later versions might work but were not tested.

## Setup

Complete the following steps before running benchmarks:

1. Install all Python dependencies:

    ```sh
    python3 -m pip install -r requirements.txt
    ```

1. Create a new project on Google Cloud Platform.
    Add the name of this project to `config.py`.
    Configure your Google Cloud SDK to use that project and enter the path of your credential file in `config.py`.

1. In your Google Cloud Platform project, activate Google Cloud Firestore in `native` mode.

1. Configure your AWS CLI with credentials for your account.
    Then enter the path to your credentials and config file in `config.py`.

1. Enter the path to your terraform binary in `config.py`.

1. Run `make` to compile all functions.

1. Go to `uc1-gcp/terraform` and run:

    ```sh
    terraform init
    TF_VAR_project=YOUR_GCP_PROJECT TF_VAR_run_name=test terraform apply
    ```

    Some steps may fail on first execution, requiring you to activate some features.
    Repeat until the deployment succeeds.
    Then destroy with:

    ```sh
    TF_VAR_project=YOUR_GCP_PROJECT TF_VAR_run_name=test terraform destroy
    ```

Note that setting up cloud infrastructure may require a credit card.
Running experiments on cloud infrastructure may incur costs.

## Running Experiments

Running experiments is straightforward:

1. Run baseline and Pub/Sub FaaS benchmarks with `python3 run_experiments_gcp.py`.
1. Run experiments with alternative runtimes with `python3 run_experiments_gcp_runtimes.py`.
1. Run experiments on AWS with `python3 run_experiments_aws.py`.

## Collecting Results

Running the experiments will create a `results` folder.
In this directory, find CSV files with cost measurements.
Experiments carry a unique identifier for each benchmark -- remove this identifier from the file names in order to analyze them.

Run the code in `show_logs.ipynb` to analyze results.
