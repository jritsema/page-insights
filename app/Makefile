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
	python -u main.py
