# XCrypto: a cryptographic ISE for RISC-V

*This project describes a complete Instruction Set Extension (ISE) for the
RISC-V architecture for accelerating cryptographic workloads. It is
accompanied by an area-optimised implementation of the ISE, which acts as
a co-processor. An example integration of the co-processor with the PicoRV32
CPU core is included.*

## Getting Started

Setup the project workspace first:

```sh
$> git clone git@github.com:scarv/xcrypto.git
$> cd xcrypto
$> git submodule update --init --recursive
$> source ./bin/source.me.sh
```

Or, look at the latest packaged release 
[here](https://github.com/scarv/xcrypto/releases).

Note that one must run the `git submodule update` command in order to
pull the external repositories (like PicoRV32) required for the integration
testbench.

Build the documentation by running `make docs`

- The ISE specification will be found in `${XC_HOME}/docs/specification.pdf`
- Documentation on the *reference implementation* of the ISE willl be found
  in `${XC_HOME}/docs/implementation.pdf`.
- Pre-built documentation for the specification and implementation can
  be found on the [releases](https://github.com/scarv/xcrypto/releases) page.

Depending on how Yosys is installed, one should also set the `YS_INSTALL`
environment variable such that `${YS_INSTALL}/yosys` is a valid path to the
`yosys` executable.

### Project Organisation

```
├── bin                     - Tool/environment setup scripts
├── docs                    - Project documentation
│   ├── diagrams
│   ├── implementation      - Reference implementation documentation
│   └── specification       - ISE Specification document
├── examples
│   ├── common              - Shared files between examples
│   └── integration-test    - "Hello World" example integration program
├── external                - External repositories
│   ├── picorv32            - Reference to the picorv32 core repo
│   └── riscv-opcodes       - Reference to the offical riscv-opcodes repo
├── flow                    - Hardware simulation/implementation flow
│   ├── gtkwave             - Wave views
│   ├── icarus              - Simulation flow
│   └── yosys               - Formal SMT2 generation and synthesis
├── rtl
│   ├── coprocessor         - XCrypto ISE example implementation
│   └── integration         - XCrypto/PicoRV32 integration example
├── verif
│   ├── formal              - Formal verification checks
│   ├── tb                  - Simulation/integration/formal testbenches
│   └── unit                - Simulation sanity tests
└── work                    - Working directory for generated artifacts
```

### Setting Up binutils

You will need a customised version of GNU Binutils in order to compile
software which uses the Crypto ISE. We modified version 2.30 of GNU
binutils, and store a patch in `external/`. 

Use the script `bin/setup-binutils.sh` as below to download, configure
and build the modified toolset.

```sh
$> cd ${XC_HOME}
$> source bin/setup-binutils.sh
```

You will end up with `as-new` in 
`${XC_HOME}/work/riscv-binutils-gdb/build/gas`. This is the assembler to use.

Other programs like `ld`/`gold` and `objdump` are in
`${XC_HOME}/work/riscv-binutils-gdb/build/binutils`.

### Running Simulations

There are two simulation testbenches for the design. The first is a set of
very basic unit tests, the second are integration tests which allow one to
run C code on a CPU and interface with the COP.

**Unit Tests**

- These use icarus verilog, and the modified binutils to run the tests
  found in `verif/unit/`.
- These are *not* correctness/compliance tests. They are used as simple 
  sanity checks during the design cycle.
- Checking for correctness should be done using the formal flow.

Building the testbench:

```sh
$> make unit_tests      # Build the unit tests
$> make icarus_build    # Build the unit test simulation testbench
```

Running the tests:

```sh
$> make icarus_run SIM_UNIT_TEST=<file> RTL_TIMEOUT=1000
$> make icarus_run_all  # Run all unit tests as a regression
```

The `<file>` path should point at a unit-test hex file, present in
`${XC_HOME}/work/unit/*.hex`. Using `${XC_HOME}` as part of an absolute path
to the hex file is advised.

**Integration Tests**

These tests work as part of an example integration of the COP with the
[picorv32](https://github.com/cliffordwolf/picorv32) core.
The integrated design subsystem is found in `rtl/integration`.

Example code to run in the integration testbench is found in 
`examples/integration-test`

Building the testbench:

```sh
$> make examples        # Build the integration test examples
$> make icarus_integ_tb # Build the integration testbench
```

Running integration tests:

```sh
$> make icarus_run_integ SIM_UNIT_TEST=<file>
```

where `<file>` points to a hex file. 
Use `${XC_HOME}/work/examples/integration-test.hex` as an example.
Waveforms will be put in `${XC_HOME}/work/icarus/integ-waves.vcd`.

## Formal testbench

Formal checks are run using Yosys and Boolector. Checks are listed in
`verif/formal/*`. A more complete description of the formal flow can
be found toward the end of the implementation document.

To run a single check, use:

```sh
$> make yosys_formal FML_CHECK_NAME=<name>
```

where `<name>` corresponds too some file called 
`verif/formal/fml_check_<name>.v`.

To run a regression of formal checks:

```sh
$> make -j 4 yosys_formal
```

will run 4 proofs in parallel. Change this number to match the available
compute resources you have. One can also run a specfic subset of the
available formal checks by delimiting the check names with spaces, and using
a backslash to escape the spaces: `FML_CHECK_NAME=check1\ check2\ check3`.

