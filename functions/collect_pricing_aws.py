import os
import sys
from urllib import request

import parse
import yaspin
import boto3

# all prices in europe-central-1 (Frankfurt)
# all prices in cents
# by the way I have no idea if these small prices lead to any precision problems
# https://aws.amazon.com/lambda/pricing/
# Frankfurt is Tier 2 pricing
PRICE_FUNCTION_INVOCATION = 20 / 1_000_000
# time is price per second
PRICE_FUNCTION_TIME = {
    "128MB": .00021,
    "256MB": .00042,
    "512MB": .00083,
    "1GB": .00167,
}

# https://aws.amazon.com/dynamodb/pricing/on-demand/
# note that data transfer is free within a region
# each query is charged like a read
PRICE_DYNAMO_READ = 30.5 / 1_000_000
PRICE_DYNAMO_WRITE = 152.5 / 1_000_000
PRICE_DYNAMO_DELETE = 152.5 / 1_000_000

# this is our default function type
FUNCTION_TYPE = "256MB"

def collect(function_name: str, function_type: str=FUNCTION_TYPE) -> None:
    os.makedirs(os.path.join(os.getcwd(), "results"), exist_ok=True)
    output_file = os.path.join(os.getcwd(), "results", function_name + "-aws.csv")

    with yaspin.yaspin(text="Collecting results") as sp:

        client = boto3.client("logs")

        logs = client.get_paginator("filter_log_events").paginate(
            logGroupName="/aws/lambda/{}".format(function_name),
            interleaved=True,
        )

        count = 0

        with open(output_file, "w") as fp:
            fp.write("timestamp,type,price,executionId\n")

            for log in logs:
                for event in log["events"]:
                    if not "message" in event or not "timestamp" in event:
                        continue

                    # have to convert from ms to ns to make pandas happy
                    timestamp = event["timestamp"] * 1e6
                    message = event["message"]

                    if "REPORT" in message:
                        requestId = message.split("REPORT RequestId: ")[1].split("	")[0]
                        p = parse.search("Billed Duration: {:d} ms", message)
                        if p is not None:
                            fp.write(f"{timestamp * 1e6},INVOCATION,{PRICE_FUNCTION_INVOCATION},{requestId}\n")
                            fp.write(f"{timestamp * 1e6},TIME,{PRICE_FUNCTION_TIME[function_type] * (p[0] / 1000)},{requestId}\n")
                            count += 1

                    elif "DYNAMO" in message:
                        requestId = message.split("(")[1].split(")")[0]

                        fp.write(f'{timestamp},{"WRITE" if "WRITE" in message else "READ"},{PRICE_DYNAMO_WRITE if "WRITE" in message else PRICE_DYNAMO_READ},{requestId}\n')

                        count += 1

                    sp.text = f"Collecting results: {count} entries parsed"

        sp.text = f"{count} entries written to {output_file}"
        sp.green.ok("✔")

if __name__ == "__main__":
    # usage: python3 collect_pricing.py <function_name> <output_file>

    if len(sys.argv) != 2:
        print("usage: python3 collect_pricing_aws.py <function_name>")
        exit(1)

    function_name = str(sys.argv[1])
    collect(function_name)
