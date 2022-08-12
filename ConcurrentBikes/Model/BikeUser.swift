//
//  BikeUser.swift
//  ConcurrentBikes
//
//  Created by Sergio Rodríguez Rama on 6/8/21.
//

import Foundation

/// Represents the city bikes' user that moves from one station to another randomly, by bike or walking when there are no bikes available.
class BikeUser: Identifiable {
    
    /// Each user individual simulation will return the
    /// time that the user waited and the number of times
    /// that it travelled by bike from one station to another.
    struct SimulationResult {
        let time: TimeInterval
        let paths: Int
    }
    
    // MARK: - Identifiable
    
    /// Identifies univocally a user.
    var id: Int
    
    // MARK: - Properties
    
    /// The waiting time in nanoseconds for moving to the
    /// next station when there are not available bikes to take
    /// or when there are no empty slots to leave the current bike.
    private let waitingTime: UInt64 = 100_000_000
    
    /// If `true`, the user is currently riding a bike.
    private var hasBike: Bool = false
    
    // MARK: - Init
    
    internal init(id: Int, hasBike: Bool = false) {
        self.id = id
        self.hasBike = hasBike
    }
    
    // MARK: - Logic
    
    /// Runs the simulation of the user moving through the area
    /// by bike, waiting to leave or take a bike when necessary.
    ///
    /// The task can be cancelled if the user reaches the goal
    /// before going through all the paths.
    ///
    /// - Parameters:
    ///
    ///   - stations: The array of stations that compounds
    ///               the area covered by the simulation.
    ///
    ///   - paths:    The number of paths that the user
    ///               must complete by bike to conclude the simulation.
    ///
    ///   - goal:     ID of the station the user wants to reach.
    ///               If `nil`, the user will run all the paths,
    ///               otherwise it will run until reaches the goal.
    ///
    ///   - logs:     If `true`, prints logs indicating the state of
    ///               the stations in every step.
    ///
    /// - Returns:    The total time in seconds waited to take or leave a bike.
    func runSimulation(
        in stations: [Station],
        paths: Int,
        goal: String? = nil,
        logs: Bool = false
    ) async -> SimulationResult {
        var totalWaitingTime: TimeInterval = 0
        var path = 0
        while path < paths, !Task.isCancelled {
            let stationIndex = Int.random(in: 0..<stations.count)
            var station = stations[stationIndex]
            if !hasBike, await station.freeBikes > 0 {
                await takeBike(from: &station, logs: logs)
            } else if hasBike, await station.emptySlots > 0 {
                await leaveBike(in: &station, logs: logs)
                path += 1
                if await station.identifier == goal {
                    withUnsafeCurrentTask { maybeUnsafeCurrentTask in
                        let task: UnsafeCurrentTask = maybeUnsafeCurrentTask! // always ok inside async function.
                        if logs { print("🚴‍♂️ \(id) 🎉🥳🎊") }
                        task.cancel()
                    }
                }
            } else {
                await wait(in: station, incrementing: &totalWaitingTime, logs: logs)
            }
        }
        return .init(time: totalWaitingTime, paths: path)
    }
    
    // MARK: - Private methods
    
    /// Waits and increments the total waiting time.
    /// - Parameters:
    ///   - station: Needed to print logs.
    ///   - totalWaitingTime: Reference to the accumulated time.
    ///   - logs: If `true`, Xcode logs are enabled, `false` by default.
    private func wait(
        in station: Station,
        incrementing totalWaitingTime: inout TimeInterval,
        logs: Bool = false
    ) async {
        if logs {
            print("\(hasBike ? "🚴‍♂️" : "🚶‍♂️") \(id) ⛔️ \(station.id)")
        }
        try? await Task.sleep(nanoseconds: waitingTime)
        totalWaitingTime += Double(waitingTime) / 1_000_000_000
    }
    
    /// Takes a bike from a station, leaving an empty slot.
    /// - Parameters:
    ///   - station: The station from which the bike will be taken.
    ///   - logs: If `true`, Xcode logs are enabled, `false` by default.
    private func takeBike(from station: inout Station, logs: Bool = false) async {
        if logs {
            print("🚶‍♂️ \(id)", terminator: " ")
        }
        await station.removeBike()
        hasBike = true
        if logs {
            let freeBikes = await station.freeBikes
            let emptySlots = await station.emptySlots
            print("🚉 \(station.id) 🚲 \(freeBikes) 🅿️ \(emptySlots)")
        }
        try? await Task.sleep(nanoseconds: waitingTime)
    }
    
    /// Leaves a bike in a station.
    /// - Parameters:
    ///   - station: The station in which the bike will be left.
    ///   - logs: If `true`, Xcode logs are enabled, `false` by default.
    private func leaveBike(in station: inout Station, logs: Bool = false) async {
        if logs {
            print("🚴‍♂️ \(id)", terminator: " ")
        }
        await station.addBike()
        hasBike = false
        if logs {
            let freeBikes = await station.freeBikes
            let emptySlots = await station.emptySlots
            print("🚉 \(station.id) 🚲 \(freeBikes) 🅿️ \(emptySlots)")
        }
        try? await Task.sleep(nanoseconds: waitingTime)
    }
}
