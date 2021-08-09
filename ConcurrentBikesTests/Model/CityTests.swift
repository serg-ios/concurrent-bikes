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
            // Get only the first 4 stations, otherwise there will be no waiting.
            let firstFourStations = city?.network.stations[0...3] ?? []
            let numberOfBikeUsers = 50
            var freeBikesInFirstFourStations = 0
            for station in firstFourStations {
                freeBikesInFirstFourStations += await station.freeBikes
            }
            // The number of bike users must be greater than the number of bikes, for ensure waiting.
            XCTAssertGreaterThan(numberOfBikeUsers, freeBikesInFirstFourStations)
            var totalWaitedTime: TimeInterval = 0
            await withTaskGroup(of: TimeInterval.self) { group in
                var bikeUsers: [BikeUser] = []
                for id in 0..<numberOfBikeUsers {
                    bikeUsers.append(BikeUser(id: id))
                }
                for bikeUser in bikeUsers {
                    group.addTask {
                        return await bikeUser.runSimulation(in: Array(firstFourStations), paths: 100)
                    }
                }
                for await timeToWait in group {
                    totalWaitedTime += timeToWait
                }
            }
            // If the number of userrs is greater than the number of bikes, there must be some waiting.
            XCTAssertGreaterThan(totalWaitedTime, 0)
        } catch {
            handleError(error)
        }
    }
    
}
