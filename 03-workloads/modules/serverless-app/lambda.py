import os
import json


def handler(_event, _context):
    workload = os.getenv("WORKLOAD")

    print(f"Hello from workload: {workload}!")

    return {
        "statusCode": 200,
        "headers": {
            "Content-Type": "application/json"
        },
        "body": json.dumps({
             "message": f"Hello from workload: {workload}",
            "status": "success",
            "static_data": True
        })
    }