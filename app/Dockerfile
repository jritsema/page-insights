FROM python:3.11-slim
COPY --from=public.ecr.aws/awsguru/aws-lambda-adapter:0.8.1 /lambda-adapter /opt/extensions/lambda-adapter
WORKDIR /app
COPY piplock.txt .
RUN pip install -r piplock.txt
COPY . .
EXPOSE 8080
CMD ["python", "-u", "main.py"]
