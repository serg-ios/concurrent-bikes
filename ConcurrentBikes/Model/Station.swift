//
//  Station.swift
//  ConcurrentBikes
//
//  Created by Sergio Rodríguez Rama on 17/7/21.
//

import Foundation
import CoreLocation

actor Station: Decodable, Identifiable {
    let id: String
    var name: String
    var latitude: CLLocationDegrees
    var longitude: CLLocationDegrees
    var freeBikes: Int
    var emptySlots: Int
    var identifier: String { id }
    
    enum CodingKeys: String, CodingKey {
        case id, name, latitude, longitude
        case freeBikes = "free_bikes"
        case emptySlots = "empty_slots"
    }
    
    func addBike() {
        freeBikes += 1
        emptySlots -= 1
    }
    
    func removeBike() {
        freeBikes -= 1
        emptySlots += 1
    }
}
