# Makefile for Governor: Deterministic Matching Engine in Standard ML

MLTON ?= mlton
POLY ?= poly
PYTHON ?= python3

BIN_DIR = bin
TARGET = $(BIN_DIR)/governor
TEST_TARGET = $(BIN_DIR)/governor_test

.PHONY: all clean test run verify format check

all: $(TARGET)

$(BIN_DIR):
	mkdir -p $(BIN_DIR)

$(TARGET): $(BIN_DIR) governor.mlb
	$(MLTON) -output $(TARGET) governor.mlb

test-compile: $(BIN_DIR) governor_test.mlb
	$(MLTON) -output $(TEST_TARGET) governor_test.mlb

test:
	@echo "Running verification and test suite..."
	$(PYTHON) tools/verify_clean_code.py
	$(POLY) --script test/run_tests.sml

run: $(TARGET)
	./$(TARGET)

verify:
	$(PYTHON) tools/verify_clean_code.py

clean:
	rm -rf $(BIN_DIR) MLB .cm test_output *.log
