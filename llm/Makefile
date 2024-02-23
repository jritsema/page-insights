all: help

.PHONY: help
help: Makefile
	@echo
	@echo " Choose a make command to run"
	@echo
	@sed -n 's/^##//p' $< | column -t -s ':' |  sed -e 's/^/ /'
	@echo

## init: run this once to initialize a new python project
.PHONY: init
init:
	python3 -m venv .venv
	direnv allow .

## install: install project dependencies
.PHONY: install
install:
	python3 -m pip install --upgrade pip
	pip install -r requirements.txt
	pip freeze > piplock.txt

## start: run local project
.PHONY: start
start:
	clear
	@echo ""
	python main.py

## build-container: package app for aws lambda using container
.PHONY: build-container
build-container:
	docker build -t lambda .

## start-container: run local project in container
.PHONY: start-container
start-container: build-container
	clear
	@echo ""
	docker run -it --rm -p 8080:8080 lambda

## deploy-container: deploy code to lambda as container - make deploy-container function=my-function
.PHONY: deploy-container
deploy-container: build-container
	./deploy.sh ${function}
