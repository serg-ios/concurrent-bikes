//
//  StationTests.swift
//  ConcurrentBikesTests
//
//  Created by Sergio Rodríguez Rama on 17/7/21.
//

import XCTest

@testable import ConcurrentBikes

class StationTests: XCTestCase {
    
    private let bundle = Bundle(for: StationTests.self)
    
    func testDecodable() async {
        do {
            let city = try await Service<City>.json(fileName: "Milano", bundle: bundle).get()
            let station = city?.network.stations.first
            XCTAssertEqual(station?.id, "b5262607c8a44db673b2f9acd3ddeede")
            XCTAssertEqual(station?.name, "Duomo")
            XCTAssertEqual(station?.emptySlots, 28)
            XCTAssertEqual(station?.freeBikes, 2)
            XCTAssertEqual(station?.latitude, 45.464683238626)
            XCTAssertEqual(station?.longitude, 9.18879747390747)
        } catch {
            handleError(error)
        }
    }
}
