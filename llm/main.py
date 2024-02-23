import os
import lambda_function

def main():

    prompt = ""
    with open("prompt.txt", "r") as f:
        prompt = f.read()

    # function accepts pointer to payload in s3
    # { "bucket": "", "key": "" }
    request = {
        "bucket": os.getenv("S3_BUCKET"),
        "key": "invoke/1708394937610335",
    }

    res = lambda_function.lambda_handler(request, {"context": True})
    print(res)


if __name__ == "__main__":
    main()
