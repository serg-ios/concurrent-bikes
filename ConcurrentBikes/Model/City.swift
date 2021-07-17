//
//  City.swift
//  ConcurrentBikes
//
//  Created by Sergio Rodríguez Rama on 17/7/21.
//

import Foundation

struct City: Decodable, Identifiable {
    var id: String { network.id }
    let network: Network
}
