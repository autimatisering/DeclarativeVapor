import XCTest

import DeclarativeAPITests

var tests = [XCTestCaseEntry]()
tests += DeclarativeAPITests.allTests()
XCTMain(tests)
