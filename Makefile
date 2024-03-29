# Helper makefile for building / testing wasm components

# Default runtime directory, override using env
RUNTIME_DIR?=./target/debug
# Default runtime executor, override using env
RUNTIME_EXEC?=wasmtime

# Build test list
TESTS=$(foreach f,$(wildcard ./spec/tests/*.toml),$(subst .toml,,$(subst ./spec/tests/,,$(f))))

# Build everything
all: runtime build-rs-tests build-as-tests


# Build the linux runtime
runtime:
	cargo build -p wasm-embedded-rt

# Run all tests
test: test-rs test-as


### Rust Tests ###

# Helper to execute a rust given test using specified runtime
RS_TEST_DIR?=target/wasm32-wasi/debug

$(RS_TEST_DIR)/test-%.wasm: hal_rs/src/tests/test_%.rs $(wildcard ./hal_rs/src/*.rs)
	cd hal_rs && cargo build --features=$(subst .rs,,$(subst hal_rs/src/tests/,,$<))

test-rs-%: $(RS_TEST_DIR)/test-%.wasm
	@echo "----------- $(RUNTIME_EXEC)/$@ (config: $(subst test-rs-,,$@).toml) -----------"
	
	$(RUNTIME_DIR)/wasm-embedded-rt --engine mock --runtime $(RUNTIME_EXEC) \
	--config ./spec/tests/$(subst test-rs-,,$@).toml \
	$(RS_TEST_DIR)/$(subst test-rs-,test-,$@).wasm

# Run all rust tests
test-rs: $(foreach f,$(TESTS),test-rs-$(f))

# Build all rust tests
build-rs-tests: $(foreach f,$(TESTS),$(RS_TEST_DIR)/test-$(f).wasm)

### AssemblyScript Tests ###

# Helper to execute a given assemblyscript test using specified runtime
AS_TEST_DIR?=./hal_as/build

# Build AssemblyScript tests
AS_TEST_SRCS=$(foreach f,$(TESTS),./hal_as/tests/test_$(f).ts)
AS_TEST_BINS := $(foreach f,$(TESTS),./hal_as/build/test-$(f).wasm)

hal_as/build/test-%.wasm: hal_as/tests/test_%.ts $(wildcard ./hal_as/assembly/*.ts)
	cd hal_as/ && npm exec asc -- ../$< -o ../$@

# Run specific assemblyscript test
test-as-%: hal_as/build/test-%.wasm
	@echo "Running $@ (config: $(subst test-as-,,$@).toml)"
	
	@echo ----------- wasmtime -----------
	$(RUNTIME_DIR)/wasm-embedded-rt --engine mock --runtime $(RUNTIME_EXEC) \
	--config ./spec/tests/$(subst test-as-,,$@).toml \
	$(AS_TEST_DIR)/$(subst test-as-,test-,$@).wasm 

# Run all assemblyscript tests
test-as: $(foreach f,$(TESTS),test-as-$(f))

# Build all assemblyscript tests
build-as-tests: $(foreach f,$(TESTS),hal_as/build/test-$(f).wasm)

.PHONY: build-rs-tests build-as-tests
