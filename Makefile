SHELL := /bin/bash
.ONESHELL:
.SHELLFLAGS := -e -c

ROOT := $(shell git rev-parse --show-toplevel)


# This section is for "make oas", which generates the oas files

OAS_DIR := $(ROOT)/photodiode/OPENIMAGESENSOR
GF_DIR := $(OAS_DIR)/gf180mcu
VENV := $(GF_DIR)/.venv

.PHONY: oas

oas:
	source $(VENV)/bin/activate
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

