import os
import sys

import parse
import google.cloud.logging
import yaspin

import config

# all prices in europe-west-3 (Frankfurt)
# all prices in cents
# by the way I have no idea if these small prices lead to any precision problems
# https://cloud.google.com/functions/pricing
# Frankfurt is Tier 2 pricing
PRICE_FUNCTION_INVOCATION = 40 / 1_000_000
# time is price per second
PRICE_FUNCTION_TIME = {
    "128MB-0.0833vCPU": .000324,
    "256MB-0.1667vCPU": .000648,
    "512MB-0.3333vCPU": .001295,
    "1024MB-0.5833vCPU": .002310,
    "2048MB-1.0vCPU": .004060,
    "4096MB-2.0vCPU": .008120,
    "8192MB-2.0vCPU": .009520,
}
# https://cloud.google.com/firestore/pricing
# note that networking is free within a region
# each query is charged like a read
PRICE_FIRESTORE_READ = 3.9 / 100_000
PRICE_FIRESTORE_WRITE = 11.7 / 100_000
PRICE_FIRESTORE_DELETE = 1.3 / 100_000

# this is the default function type
FUNCTION_TYPE = "256MB-0.1667vCPU"

def collect(function_name: str, function_type: str=FUNCTION_TYPE) -> None:
    os.makedirs(os.path.join(os.getcwd(), "results"), exist_ok=True)
    output_file = os.path.join(os.getcwd(), "results", function_name + "-gcp.csv")

    with yaspin.yaspin(text="Collecting results") as sp:

        # get logs for function
        logging_client = google.cloud.logging.Client()

        entries = logging_client.list_entries(
            resource_names=[f"projects/{config.GCLOUD_PROJECT}"],
            filter_=f"resource.type=\"cloud_function\" AND resource.labels.function_name=\"{function_name}\"",
            page_size=1000,
        )

        with open(output_file, "w") as fp:
            fp.write("timestamp,type,price,executionId\n")

            # parse logs
            count = 0

            for e in entries:
                sp.text = f"Collecting results: {count} entries parsed"

                if type(e) is google.cloud.logging.TextEntry:
                    if "FIRESTORE OP READ" in e.payload:
                        fp.write(f"{e.timestamp},READ,{PRICE_FIRESTORE_READ},{e.labels['execution_id']}\n")
                        count += 1
                    elif "FIRESTORE OP WRITE" in e.payload:
                        fp.write(f"{e.timestamp},WRITE,{PRICE_FIRESTORE_WRITE},{e.labels['execution_id']}\n")
                        count += 1
                    elif "FIRESTORE OP DELETE" in e.payload:
                        fp.write(f"{e.timestamp},DELETE,{PRICE_FIRESTORE_DELETE},{e.labels['execution_id']}\n")
                        count += 1
                    else:
                        p = parse.search("Function execution took {:d} ms", e.payload)

                        if p is not None:
                            fp.write(f"{e.timestamp},INVOCATION,{PRICE_FUNCTION_INVOCATION},{e.labels['execution_id']}\n")
                            fp.write(f"{e.timestamp},TIME,{PRICE_FUNCTION_TIME[function_type] * (p[0] / 1000)},{e.labels['execution_id']}\n")
                            count += 2

        sp.text = f"{count} entries written to {output_file}"
        sp.green.ok("✔")

if __name__ == "__main__":
    # usage: python3 collect_pricing.py <function_name> <output_file>

    if len(sys.argv) != 2:
        print("usage: python3 collect_pricing_gcp.py <function_name>")
        exit(1)

    function_name = str(sys.argv[1])
    collect(function_name)