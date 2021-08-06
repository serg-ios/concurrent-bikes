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
    
    func testSimulation() async {
        do {
            let city = try await Service<City>.json(fileName: "Milano", bundle: bundle).get()
            let firstFourStations = city?.network.stations[0...3] ?? []
            var freeBikesInFirstFourStations = 0
            for station in firstFourStations {
                freeBikesInFirstFourStations += await station.freeBikes
            }
            XCTAssertEqual(37, freeBikesInFirstFourStations)
            var totalTimeToWait: TimeInterval = 0
            await withTaskGroup(of: TimeInterval.self) { group in
                var bikeUsers: [BikeUser] = []
                for id in 0..<50 {
                    bikeUsers.append(BikeUser(id: id))
                }
                for bikeUser in bikeUsers {
                    group.async {
                        return await bikeUser.runSimulation(in: Array(firstFourStations), paths: 100)
                    }
                }
                for await timeToWait in group {
                    totalTimeToWait += timeToWait
                }
            }
            XCTAssertGreaterThan(0, totalTimeToWait)
        } catch {
            handleError(error)
        }
    }
    
}
