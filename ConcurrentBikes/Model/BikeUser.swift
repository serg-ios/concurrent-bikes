//
//  BikeUser.swift
//  ConcurrentBikes
//
//  Created by Sergio Rodríguez Rama on 6/8/21.
//

import Foundation

class BikeUser: Thread, Identifiable {
    
    var id: Int
    
    private let waitingTime = 0.1
    private var hasBike: Bool = false
    
    internal init(id: Int, hasBike: Bool = false) {
        self.id = id
        self.hasBike = hasBike
    }
    
    func runSimulation(in stations: [Station], paths: Int) async -> TimeInterval {
        var totalWaitingTime: TimeInterval = 0
        for path in 0..<paths {
            let stationIndex = Int.random(in: 0..<stations.count)
            let nextStation = stations[stationIndex]
            mainloop: while true {
                switch hasBike {
                case false:
                    if await nextStation.freeBikes > 0 {
                        await nextStation.removeBike()
                        hasBike = true
                        print("BikeUser \(id) takes a bike in station \(stationIndex) to make path \(path).")
                        break mainloop
                    } else {
                        print("BikeUser \(id) waits to take a bike in station \(stationIndex) to make path \(path).")
                        BikeUser.sleep(forTimeInterval: waitingTime)
                        totalWaitingTime += waitingTime
                    }
                case true:
                    if await nextStation.emptySlots > 0 {
                        await nextStation.addBike()
                        hasBike = false
                        print("BikeUser \(id) leaves a bike in station \(stationIndex) to make path \(path).")
                        break mainloop
                    } else {
                        print("BikeUser \(id) waits to leave a bike in station \(stationIndex) to make path \(path).")
                        BikeUser.sleep(forTimeInterval: waitingTime)
                        totalWaitingTime += waitingTime
                    }
                }
            }
        }
        return totalWaitingTime
    }
}
