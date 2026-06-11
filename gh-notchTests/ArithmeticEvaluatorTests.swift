import XCTest
@testable import gh_notch

final class ArithmeticEvaluatorTests: XCTestCase {

    func testAddition() {
        XCTAssertEqual(ArithmeticEvaluator.evaluate("2 + 2"), 4)
    }

    func testOperatorPrecedence() {
        XCTAssertEqual(ArithmeticEvaluator.evaluate("2 + 3 * 4"), 14)
    }

    func testParentheses() {
        XCTAssertEqual(ArithmeticEvaluator.evaluate("(2 + 3) * 4"), 20)
    }

    func testUnaryMinus() {
        XCTAssertEqual(ArithmeticEvaluator.evaluate("-5 + 8"), 3)
    }

    func testDecimals() {
        guard let value = ArithmeticEvaluator.evaluate("0.5 * 3") else {
            return XCTFail("expected a value")
        }
        XCTAssertEqual(value, 1.5, accuracy: 0.0001)
    }

    func testNestedParentheses() {
        XCTAssertEqual(ArithmeticEvaluator.evaluate("((1 + 2) * (3 + 4))"), 21)
    }

    func testDivisionByZeroIsNil() {
        XCTAssertNil(ArithmeticEvaluator.evaluate("1 / 0"))
    }

    func testMalformedInputIsNil() {
        XCTAssertNil(ArithmeticEvaluator.evaluate("2 +"))
        XCTAssertNil(ArithmeticEvaluator.evaluate("hello"))
        XCTAssertNil(ArithmeticEvaluator.evaluate("(1 + 2"))
        XCTAssertNil(ArithmeticEvaluator.evaluate("2 2"))
        XCTAssertNil(ArithmeticEvaluator.evaluate(""))
    }
}
