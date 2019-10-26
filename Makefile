# Makefile for Governor: Deterministic Matching Engine in Standard ML

MLTON ?= mlton
POLY ?= poly
PYTHON ?= python3

BIN_DIR = bin
TARGET = $(BIN_DIR)/governor

.PHONY: all clean test test-props test-stress bench sim run verify

all: $(TARGET)

$(BIN_DIR):
	mkdir -p $(BIN_DIR)

$(TARGET): $(BIN_DIR) governor.mlb
	$(MLTON) -output $(TARGET) governor.mlb

test: verify
	@echo "Executing master test suite..."
	$(POLY) --script test/run_tests.sml

test-props: verify
	@echo "Executing property-based tests..."
	$(POLY) --script test/test_properties_rbtree.sml
	$(POLY) --script test/test_properties_matching.sml

test-stress: verify
	@echo "Executing 50,000-order stress harness..."
	$(POLY) --script test/test_stress.sml

bench: $(TARGET)
	@echo "Executing 100,000-order native benchmark..."
	./$(TARGET) --bench 100000

sim: $(TARGET)
	@echo "Executing market simulation..."
	./$(TARGET) --sim 1000

run: $(TARGET)
	./$(TARGET)

verify:
	$(PYTHON) tools/verify_clean_code.py

clean:
	rm -rf $(BIN_DIR) MLB .cm test_output *.log
