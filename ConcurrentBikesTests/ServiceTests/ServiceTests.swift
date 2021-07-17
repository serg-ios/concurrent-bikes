//
//  ServiceTests.swift
//  ConcurrentBikesTests
//
//  Created by Sergio Rodríguez Rama on 17/7/21.
//

import XCTest

@testable import ConcurrentBikes

class ServiceTests: XCTestCase {
    
    private let bundle = Bundle(for: ServiceTests.self)
    
    func testMissingFileErrorThrown() {
        XCTAssertThrowsError(
            try Service<City>.json(fileName: "Madrid", bundle: bundle).get(),
            "Madrid.json not found, as expected, error is thrown."
        ) { error in
            let expectedError = ServiceError.missingFile("Madrid.json")
            XCTAssertEqual(error as? ServiceError, expectedError)
        }
    }
    
    func testDecodingErrorThrown() {
        let fileName = "InvalidJson"
        XCTAssertThrowsError(
            try Service<City>.json(fileName: fileName, bundle: bundle).get(),
            "\(fileName).json can't be decoded, as expected, error is thrown."
        ) { error in
            XCTAssertNotNil(error as? DecodingError)
        }
    }
}
