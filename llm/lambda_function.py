import os 
import json
from datetime import datetime
import boto3
from litellm import completion

s3 = boto3.client("s3")

def get_s3_key(id):
    return f"{id}.json"


def inference(prompt, model, temperature=0):
    msg = [{"role": "user", "content": prompt, }]
    res = completion(model=model, messages=msg,
                     max_tokens=4096, temperature=temperature)
    result = res.choices[0].message.content
    print(result)
    return result


# lambda entrypoint
def lambda_handler(request, context):
    print("lambda_function.lambda_handler")
    print(json.dumps(request, indent=2))

    # fetch invoke payload from s3 (due to 256k limit)
    bucket = request["bucket"]
    invoke_key = request["key"]
    print(f"reading s3://{bucket}/{invoke_key}")
    obj = s3.get_object(Bucket=bucket, Key=invoke_key)
    request = json.loads(obj["Body"].read())
    id = request["id"]
    model = request["model"]
    prompt = request["prompt"]

    print(f'summarizing using {model}')
    start = datetime.now()
    summary = inference(prompt, model, temperature=1)
    end = datetime.now()
    elapsed = end - start
    print(f"summary took {elapsed}")

    # fetch data record from s3
    key = get_s3_key(id)
    print(f"reading s3://{bucket}/{key}")
    obj = s3.get_object(Bucket=bucket, Key=key)
    record = json.loads(obj["Body"].read())

    # update summary and status
    record["summary"] = summary.strip()
    record["status"] = "Complete"
    record["model"] = model

    # update record in s3
    print(f"writing s3://{bucket}/{key}")
    s3.put_object(Body=json.dumps(record, indent=2),
                  Bucket=bucket, Key=key,
                  ContentType="application/json")

    # delete invoke payload from s3
    print(f"deleting s3://{bucket}/{invoke_key}")
    s3.delete_object(Bucket=bucket, Key=invoke_key)

    print("done")
