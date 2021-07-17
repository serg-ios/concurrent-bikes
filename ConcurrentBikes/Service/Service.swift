//
//  Service.swift
//  ConcurrentBikes
//
//  Created by Sergio Rodríguez Rama on 17/7/21.
//

import Foundation

struct Service<T: Decodable> {
    let get: () -> T?
}

extension Service {
    static func json(fileName: String, bundle: Bundle) throws -> Self {
        // Look for the file, throw an error if the file is missing.
        guard let url = bundle.url(forResource: fileName, withExtension: "json") else {
            throw ServiceError.missingFile("\(fileName).json")
        }
        // Convert file to Data. Force unwrap makes sense because if the file exists, the data must be valid.
        let data: Data = try! Data(contentsOf: url)
        // Decode Data, throw a DecodingError if there is a problem.
        do {
            let decoded = try JSONDecoder().decode(T.self, from: data)
            return .init(get: { decoded })
        }
    }
}
