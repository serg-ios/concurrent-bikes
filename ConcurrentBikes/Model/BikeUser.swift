//
//  BikeUser.swift
//  ConcurrentBikes
//
//  Created by Sergio Rodríguez Rama on 6/8/21.
//

import Foundation

class BikeUser: Identifiable {
    
    var id: Int
    
    private let waitingTime = 0.00000002
    private var hasBike: Bool = false
    
    internal init(id: Int, hasBike: Bool = false) {
        self.id = id
        self.hasBike = hasBike
    }
    
    /// Runs the simulation of the user moving through the area by bike, waiting to leave or take a bike when necessary.
    /// - Parameters:
    ///   - stations: The array of stations that compounds the area covered by the simulation.
    ///   - paths: The number of paths that the user must complete by bike to conclude the simulation.
    /// - Returns: The total time waited to take or leave a bike.
    func runSimulation(in stations: [Station], paths: Int) async -> TimeInterval {
        var totalWaitingTime: TimeInterval = 0
        for _ in 0..<paths {
            var stationIndex = Int.random(in: 0..<stations.count)
            var nextStation = stations[stationIndex]
            mainloop: while true {
                switch hasBike {
                case false:
                    if await nextStation.freeBikes > 0 {
                        await nextStation.removeBike()
                        hasBike = true
                        await Task.sleep(.random(in: 0...20))
                        break mainloop
                    } else {
                        await Task.sleep(.random(in: 0...20))
                        totalWaitingTime += waitingTime
                        stationIndex = Int.random(in: 0..<stations.count)
                        nextStation = stations[stationIndex]
                    }
                case true:
                    if await nextStation.emptySlots > 0 {
                        await nextStation.addBike()
                        hasBike = false
                        await Task.sleep(.random(in: 0...20))
                        break mainloop
                    } else {
                        await Task.sleep(.random(in: 0...20))
                        totalWaitingTime += waitingTime
                        stationIndex = Int.random(in: 0..<stations.count)
                        nextStation = stations[stationIndex]
                    }
                }
            }
        }
        return totalWaitingTime
    }
}
