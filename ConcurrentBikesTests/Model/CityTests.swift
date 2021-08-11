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
    
    func testGetFromJson() async {
        do {
            let city = try await Service<City>.get(
                from: "Milano",
                bundle: bundle
            ).get()
            XCTAssertEqual(city?.id, "bikemi")
        } catch {
            handleError(error)
        }
    }
}
