//
//  BikeUserTests.swift
//  BikeUserTests
//
//  Created by Sergio Rodríguez Rama on 10/8/21.
//

import XCTest

@testable import ConcurrentBikes

class BikeUserTests: XCTestCase {
    
    private let bundle = Bundle(for: CityTests.self)
    
    func testSimulationWaiting() async {
        do {
            let city = try await Service<City>.json(fileName: "Milano", bundle: bundle).get()
            // Get only the first 4 stations, otherwise there will be too many bikes.
            let firstFourStations = city?.network.stations[0...3] ?? []
            let numberOfBikeUsers = 50
            let pathsPerUser = 10
            var freeBikesInFirstFourStations = 0
            for station in firstFourStations {
                freeBikesInFirstFourStations += await station.freeBikes
            }
            // The number of bike users must be greater than the number of bikes, to ensure waiting.
            XCTAssertGreaterThan(numberOfBikeUsers, freeBikesInFirstFourStations)
            // Total time waited by all users must be greater than zero because there are more users than bikes.
            var totalWaitedTime: TimeInterval = 0
            // Total number of paths run by all the users during the simulation.
            var totalPathsRun = 0
            var bikeUsers: [BikeUser] = []
            for id in 0..<numberOfBikeUsers {
                bikeUsers.append(BikeUser(id: id))
            }
            // Create a task group to run all the simulations concurrently.
            await withTaskGroup(of: BikeUser.SimulationResult.self) { group in
                for bikeUser in bikeUsers {
                    group.addTask {
                        // All these async tasks will run concurrently.
                        return await bikeUser.runSimulation(
                            in: Array(firstFourStations),
                            paths: pathsPerUser,
                            logs: true
                        )
                    }
                }
                for await simulationResult in group {
                    // The result of every concurrent simulation will be collected here and accumulated.
                    totalWaitedTime += simulationResult.time
                    totalPathsRun += simulationResult.paths
                }
            }
            // If the number of users is greater than the number of bikes, there must be some waiting.
            XCTAssertGreaterThan(totalWaitedTime, 0)
            // When there is no goal, the user runs all the paths.
            XCTAssertEqual(totalPathsRun, numberOfBikeUsers * pathsPerUser)
        } catch {
            handleError(error)
        }
    }

    func testSimulationNoWaiting() async {
        do {
            let city = try await Service<City>.json(fileName: "Milano", bundle: bundle).get()
            // Get only one station, to easily avoid waiting.
            let stations = [city?.network.stations[1]].compactMap({$0})
            let numberOfBikeUsers = 18
            let pathsPerUser = 10
            let freeBikes = await stations.first?.freeBikes
            // The number of bikes has to be greater than the number of users for the waiting time to be zero.
            XCTAssertGreaterThan(freeBikes ?? 0, numberOfBikeUsers)
            // Total time waited by all users will be zero: there are more bikes than users and only one station.
            var totalWaitedTime: TimeInterval = 0
            // Total number of paths run by all the users during the simulation.
            var totalPathsRun = 0
            var bikeUsers: [BikeUser] = []
            for id in 0..<numberOfBikeUsers {
                bikeUsers.append(BikeUser(id: id))
            }
            // Create a task group to run all the simulations concurrently.
            await withTaskGroup(of: BikeUser.SimulationResult.self) { group in
                for bikeUser in bikeUsers {
                    group.addTask {
                        // All these async tasks will run concurrently.
                        return await bikeUser.runSimulation(in: stations, paths: pathsPerUser, logs: true)
                    }
                }
                for await simulationResult in group {
                    // The result of every concurrent simulation will be collected here and accumulated.
                    totalWaitedTime += simulationResult.time
                    totalPathsRun += simulationResult.paths
                }
            }
            // Total waiting time must be 0.
            XCTAssertEqual(totalWaitedTime, 0)
            // When there is no goal, the user runs all the paths.
            XCTAssertEqual(totalPathsRun, numberOfBikeUsers * pathsPerUser)
        } catch {
            handleError(error)
        }
    }
    
    func testSimulationWithGoal() async {
        do {
            let city = try await Service<City>.json(fileName: "Milano", bundle: bundle).get()
            // Get only the first 2 stations, so there are high chances to reach the goal by at least one user.
            let stations = Array(city?.network.stations[0...1] ?? [])
            let numberOfBikeUsers = 20
            let pathsPerUser = 10
            // Total number of paths run by all the users during the simulation.
            var totalPathsRun = 0
            var bikeUsers: [BikeUser] = []
            for id in 0..<numberOfBikeUsers {
                bikeUsers.append(BikeUser(id: id))
            }
            // Create a task group to run all the simulations concurrently.
            await withTaskGroup(of: BikeUser.SimulationResult.self) { group in
                for bikeUser in bikeUsers {
                    group.addTask {
                        // All these async tasks will run concurrently.
                        return await bikeUser.runSimulation(
                            in: stations,
                            paths: pathsPerUser,
                            goal: stations.first?.identifier,
                            logs: true
                        )
                    }
                }
                for await simulationResult in group {
                    // The result of every concurrent simulation will be collected here and accumulated.
                    totalPathsRun += simulationResult.paths
                }
            }
            // When there is a goal, the user may not run all the paths.
            XCTAssertLessThan(totalPathsRun, numberOfBikeUsers * pathsPerUser)
        } catch {
            handleError(error)
        }
    }
}
