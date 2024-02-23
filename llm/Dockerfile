FROM public.ecr.aws/lambda/python:3.11
RUN yum update -y && yum clean all
COPY piplock.txt ./
RUN pip install --upgrade pip
RUN pip install -r piplock.txt
COPY *.py ./
CMD ["lambda_function.lambda_handler"]
