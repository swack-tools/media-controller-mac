# Shield Pause Tests

This directory contains the test suite for the Shield Pause CLI application.

## Test Structure

```
Tests/
└── ShieldPauseTests/
    ├── BasicTests.swift           # Infrastructure verification tests
    ├── ValidatorsTests.swift      # IP and PIN validation tests
    └── ConfigurationTests.swift   # Configuration management tests
```

## Running Tests

### Using Just

```bash
# Run all tests
just test

# Run tests with verbose output
just test-verbose

# Generate code coverage
just coverage
```

### Using Swift Package Manager

```bash
# Run all tests
swift test

# Run tests with verbose output
swift test --verbose

# Run specific test
swift test --filter ValidatorsTests

# Run with code coverage
swift test --enable-code-coverage
```

### Using Xcode

```bash
# Generate Xcode project
just xcode

# Open in Xcode
just open

# Then: Cmd+U to run tests
```

## Test Coverage

### BasicTests.swift

Simple tests to verify the test infrastructure is working correctly:
- ✅ Basic assertions
- ✅ String operations
- ✅ Array/Dictionary operations
- ✅ Boolean logic
- ✅ Async/await support
- ✅ Performance measurements
- ✅ Error handling

### ValidatorsTests.swift

Tests for IP address and PIN validation:

**IP Address Validation:**
- ✅ Valid IPv4 addresses (192.168.1.1, 10.0.0.1, etc.)
- ✅ Invalid formats (wrong octets, missing parts, non-numeric)
- ✅ Edge cases (0.0.0.0, 255.255.255.255)

**PIN Validation:**
- ✅ Valid 6-character hexadecimal PINs
- ✅ Invalid PINs (wrong length, non-hex characters)
- ✅ Case insensitivity (uppercase/lowercase)
- ✅ Edge cases (spaces, special characters)

**Performance:**
- ✅ IP validation performance benchmark
- ✅ PIN validation performance benchmark

### ConfigurationTests.swift

Tests for configuration management:

**Loading Configuration:**
- ✅ Load when no .env file exists
- ✅ Load from valid .env file
- ✅ Handle whitespace in config
- ✅ Handle comments in config
- ✅ Handle empty lines

**Saving Configuration:**
- ✅ Save configuration to .env
- ✅ Round-trip (save and load)
- ✅ Save empty configuration

**Certificate Management:**
- ✅ Check certificate existence
- ✅ Save certificate data
- ✅ Save private key data
- ✅ Read certificate data
- ✅ Read private key data
- ✅ Delete certificates
- ✅ Handle missing certificates

**File Paths:**
- ✅ Correct config directory
- ✅ Correct file URLs

## Current Status

⚠️ **Note:** Tests are currently not running due to AndroidTVRemoteControl library compilation issues. The library has macOS availability problems that prevent compilation.

**What Works:**
- ✅ Test structure is correct
- ✅ BasicTests.swift passes (no dependencies)
- ✅ ValidatorsTests.swift is ready (waiting for library fix)
- ✅ ConfigurationTests.swift is ready (waiting for library fix)

**What Needs Fixing:**
- ❌ AndroidTVRemoteControl library needs macOS availability annotations
- See README_SWIFT.md for details on fixing the library

## Writing New Tests

### Test File Template

```swift
import XCTest
@testable import ShieldPauseCore

final class MyFeatureTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Set up test fixtures
    }

    override func tearDown() {
        // Clean up
        super.tearDown()
    }

    func testSomething() {
        // Arrange
        let input = "test"

        // Act
        let result = MyFeature.process(input)

        // Assert
        XCTAssertEqual(result, "expected")
    }

    func testPerformance() {
        measure {
            // Code to benchmark
        }
    }
}
```

### Best Practices

1. **Use Descriptive Names:** `testValidIPv4Addresses` not `testIP1`
2. **Arrange-Act-Assert:** Structure tests clearly
3. **Test One Thing:** Each test should verify one behavior
4. **Use setUp/tearDown:** For common setup/cleanup
5. **Clean Up:** Remove test files created during tests
6. **Test Edge Cases:** Empty strings, nil, max values, etc.
7. **Performance Tests:** Use `measure` blocks for benchmarks
8. **Async Tests:** Use `async throws` for async code

### Common XCTest Assertions

```swift
// Equality
XCTAssertEqual(actual, expected)
XCTAssertNotEqual(actual, unexpected)

// Boolean
XCTAssertTrue(condition)
XCTAssertFalse(condition)

// Nil checks
XCTAssertNil(value)
XCTAssertNotNil(value)

// Errors
XCTAssertThrowsError(try someFunction())
XCTAssertNoThrow(try someFunction())

// Comparisons
XCTAssertGreaterThan(a, b)
XCTAssertLessThan(a, b)
```

## Test Count

- **Total Test Files:** 3
- **Total Test Cases:** 40+
- **Coverage Goal:** 80%+

## CI Integration

Tests are integrated into the `just ci` command:

```bash
just ci  # Runs: clean → build → test → lint
```

## Future Tests

Planned test additions:
- [ ] ShieldRemoteTests (when library is fixed)
- [ ] CommandLineTests (argument parsing)
- [ ] Integration tests (full workflow)
- [ ] Mock Shield TV server for end-to-end testing

## References

- [XCTest Documentation](https://developer.apple.com/documentation/xctest)
- [Swift Testing Best Practices](https://developer.apple.com/documentation/xctest/defining_test_cases_and_test_methods)
- [Test-Driven Development](https://en.wikipedia.org/wiki/Test-driven_development)
