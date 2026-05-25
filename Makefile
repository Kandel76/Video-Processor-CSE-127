SHELL := /bin/bash
.ONESHELL:
.SHELLFLAGS := -e -c

ROOT := $(shell git rev-parse --show-toplevel)

# This section is for "make oas", which generates the oas files

OAS_DIR := $(ROOT)/photodiode/OAS_Sensor
GF_DIR := $(OAS_DIR)/gf180mcu
VENV := $(ROOT)/.venv
GFENV :=$(GF_DIR)/.venv

.PHONY: setup gf180 oas

setup:
	curl -LsSf https://astral.sh/uv/install.sh | sh
	uv venv --python 3.12
	source $(VENV)/bin/activate
	uv pip install gdsfactory

gf180:
	cd $(GF_DIR)
	git checkout ethan_branch
	make
	uv sync
	source $(GFENV)/bin/activate

oas: 
	cd $(OAS_DIR)
	python3 test.py
	deactivate

# This section is for "make lef", which generates the lef file

PHOTO_DIR :=$(ROOT)/photodiode

.PHONY: lef

lef:
	source $(VENV)/bin/activate
	cd $(PHOTO_DIR)
	python3 photodiode_lef_generator.py
	deactivate
# For future sections
