//
//  Station.swift
//  ConcurrentBikes
//
//  Created by Sergio Rodríguez Rama on 17/7/21.
//

import Foundation
import CoreLocation

struct Station: Decodable, Identifiable {
    let id: String
    let name: String
    let latitude: CLLocationDegrees
    let longitude: CLLocationDegrees
    var freeBikes: Int
    var emptySlots: Int
    
    enum CodingKeys: String, CodingKey {
        case id, name, latitude, longitude
        case freeBikes = "free_bikes"
        case emptySlots = "empty_slots"
    }
}
