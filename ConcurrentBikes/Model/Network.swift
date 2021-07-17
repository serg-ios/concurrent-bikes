//
//  Network.swift
//  ConcurrentBikes
//
//  Created by Sergio Rodríguez Rama on 17/7/21.
//

import Foundation

struct Network: Decodable, Identifiable {
    let id: String
    let stations: [Station]
}
