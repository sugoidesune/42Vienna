# IRC Tester Suite

A comprehensive test framework for 42 IRC (`ircserv` / `ft_irc`).

## Quick Start

### 1. Start Your IRC Server
From repository root:
```bash
./ircserv 6667 1234
```

### 2. Enter Tester Directory & Build
```bash
cd tester
make
```

### 3. Run Tests
The top-level `Makefile` is the single entry point for all tests:

```bash
# Run all scenario tests
make run

# Run a specific test case or folder
make case 5
make run registration
make runv commands/01_ping.spec    # verbose output

# Run scenarios in parallel
make parallel

# Run standalone suites
make memory                       # Memory leaks & DoS stress tests
make lifecycle                    # Server start/stop & edge-case checks
make concurrency                  # Multi-client concurrency tests

# Run all 3 main test suites (scenario, memory, lifecycle)
make full

# Clean build artifacts
make clean
make fclean
```

---

## Directory Structure

```text
tester/
├── Makefile                      # Top-level unified command center
├── README.md                     # Documentation & usage guide
├── .gitignore                    # Build artifact ignore list
├── .testignore                   # Ignored test specifications
│
├── scenario_tester/              # Scenario testing engine & test catalog
│   ├── scenarios/                # .spec scenario files (registration, commands, channels, etc.)
│   ├── testrunner.cpp            # Core C++ scenario execution engine
│   ├── run_scenarios             # Sequential scenario runner script
│   ├── run_parallel              # Parallel scenario runner script
│   └── TESTCASE_SYNTAX.md        # Complete guide to writing .spec tests
│
└── standalone/                   # Standalone stress, lifecycle & concurrency tests
    ├── concurrency_tester.cpp    # Multi-client concurrency tester
    ├── ensure_server.sh          # Server startup & lifecycle helper wrapper
    ├── test_server_lifecycle.sh  # Argument parsing, signal handling & crash safety
    └── test_memory_dos.py        # Connection exhaustion & RSS memory leak tests
```

---

## Adding New Scenario Tests

1. Create a `.spec` file in the appropriate subfolder inside `scenario_tester/scenarios/`, for example:
   ```bash
   scenario_tester/scenarios/registration/99_custom_test.spec
   ```
2. See [TESTCASE_SYNTAX.md](scenario_tester/TESTCASE_SYNTAX.md) for detailed directive syntax (`SEND`, `EXPECT`, `SEND_RAW`, `FLOOD`, `TIMEOUT`, etc.).
3. Run your new test directly:
   ```bash
   make case 99_custom_test
   ```
