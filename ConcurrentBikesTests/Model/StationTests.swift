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
            let emptySlots = await station?.emptySlots
            let freeBikes = await station?.freeBikes
            let stationId = await station?.identifier
            let stationName = await station?.name
            let stationLatitude = await station?.latitude
            let stationLongitude = await station?.longitude
            XCTAssertEqual(stationId, "b5262607c8a44db673b2f9acd3ddeede")
            XCTAssertEqual(stationName, "Duomo")
            XCTAssertEqual(emptySlots, 28)
            XCTAssertEqual(freeBikes, 2)
            XCTAssertEqual(stationLatitude, 45.464683238626)
            XCTAssertEqual(stationLongitude, 9.18879747390747)
        } catch {
            handleError(error)
        }
    }
}
