from flask import Flask, request, render_template, Response
from flask_cors import CORS
import markdown
from litellm import completion
import json
import os
from datetime import datetime
import boto3

app = Flask(__name__)
# CORS(app, resources={r"/*": {"origins": "*"}})
CORS(app)

# s3
s3 = boto3.client("s3")
bucket = os.getenv("S3_BUCKET")
print(f"S3_BUCKET = {bucket}")

lambda_client = boto3.client("lambda")

def get_s3_key(id):
    return f"{id}.json"

def get_pages():
    pages = []
    print(f"listing s3://{bucket}")
    objects = s3.list_objects(Bucket=bucket)
    if "Contents" in objects:
        for obj in objects["Contents"]:
            key = obj["Key"]
            if key.endswith(".json"):
                print(f"fetching s3://{bucket}/{key}")
                obj = s3.get_object(Bucket=bucket, Key=key)
                json_str = obj['Body'].read().decode('utf-8')
                d = json.loads(json_str)
                d["html"] = markdown.markdown(d["summary"])
                status = d["status"]
                if status == "Complete":
                    d["badge"] = "bg-success"
                elif status == "Processing":
                    d["badge"] = "bg-primary"
                pages.append(d)

        # sort pages by timestamp
        pages.sort(key=lambda x: x["timestamp"], reverse=True)
    return pages


@app.route("/")
def index():
    return render_template("index.html", pages=get_pages())


@app.route("/insights", methods=["POST"])
def insights():

    # generate id for this request
    timestamp = str(datetime.now().timestamp())
    id = timestamp.replace(".", "")

    # build payload for async lambda
    # write payload to s3
    # since async lambda has a max payload size of 256k,
    # html can be quite large (up to 10mb which APIG supports)
    html = request.data.decode('utf-8')
    invoke_request = {
        "id": id,
        "prompt": f"Summarize the following web page.\n\n {html}",
        "model": request.args.get("model"),
    }
    key = f"invoke/{id}"
    print(f"writing s3://{bucket}/{key}")
    s3.put_object(Body=json.dumps(invoke_request, indent=2),
                  Bucket=bucket, Key=key,
                  ContentType="application/json")

    # invoke the llm lambda asynchronously 
    # with a pointer to the invoke request in s3
    payload = {"bucket": bucket, "key": key}
    lambda_client.invoke(
        FunctionName=os.getenv("LAMBDA_FUNCTION"),
        InvocationType="Event",
        Payload=json.dumps(payload))

    # build data record that represents this request
    url = request.args.get("url")
    title = request.args.get("title")
    result = {
        "id": id,
        "url": url,
        "title": title,
        "timestamp": timestamp,
        "status": "Processing",
        "summary": "",
    }
    key = get_s3_key(id)
    print(f"writing s3://{bucket}/{key}")
    s3.put_object(Body=json.dumps(result, indent=2),
                  Bucket=bucket, Key=key,
                  ContentType="application/json")

    return result


@app.route("/pages/<id>", methods=["GET"])
def pages_get(id):
    key = get_s3_key(id)
    print(f"fetching s3://{bucket}/{key}")
    obj = s3.get_object(Bucket=bucket, Key=key)
    return Response(obj["Body"].read().decode('utf-8'), mimetype='application/json')


@app.route("/pages/<id>", methods=["DELETE"])
def pages_delete(id):
    key = get_s3_key(id)
    print(f"deleting s3://{bucket}/{key}")
    s3.delete_object(Bucket=bucket, Key=key)
    return ""


port = os.getenv("PORT", 8080)
print(f"listening on http://localhost:{port}")
app.run(host="0.0.0.0", port=port)
