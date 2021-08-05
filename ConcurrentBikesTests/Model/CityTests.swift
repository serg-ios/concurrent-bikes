//
//  CityTests.swift
//  ConcurrentBikesTests
//
//  Created by Sergio Rodríguez Rama on 17/7/21.
//

import XCTest

@testable import ConcurrentBikes

class CityTests: XCTestCase {
    
    private let bundle = Bundle(for: CityTests.self)
    
    func testDecodable() async {
        do {
            let city = try await Service<City>.json(fileName: "Milano", bundle: bundle).get()
            XCTAssertEqual(city?.id, "bikemi")
        } catch {
            handleError(error)
        }
    }
}
