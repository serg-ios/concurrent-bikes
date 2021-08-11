//
//  Service.swift
//  ConcurrentBikes
//
//  Created by Sergio Rodríguez Rama on 17/7/21.
//

import Foundation

/// Generic protocol witness to abstract data collection.
struct Service<T: Decodable> {
    /// Use this completion handler to return asynchronously the data requested.
    let get: () async -> T?
}

extension Service {

    /// Obtains data from a json file.
    /// - Parameters:
    ///   - jsonFileName: The name of this file without extension.
    ///   - bundle: The bundle in which the file is located.
    /// - Returns: Returns the decoded data.
    static func get(from jsonFileName: String, bundle: Bundle) throws -> Self {
        // Look for the file, throw an error if the file is missing.
        guard let url = bundle.url(forResource: jsonFileName, withExtension: "json") else {
            throw ServiceError.missingFile("\(jsonFileName).json")
        }
        // Convert file to Data. Force unwrap makes sense because if the file exists,
        // the data can't be nil.
        let data: Data = try! Data(contentsOf: url)
        // Decode data, throw a DecodingError if there is a problem.
        do {
            let decoded = try JSONDecoder().decode(T.self, from: data)
            return .init(get: { decoded })
        }
    }
    
    /// Obtains data from an URL using shared URLSession.
    /// - Parameter url: The URL from which the data will be requested.
    /// - Returns: Returns de decoded data.
    static func get(from url: URL) async throws -> Self {
        let (data, _) = try await URLSession.shared.data(from: url)
        let decoded = try JSONDecoder().decode(T.self, from: data)
        return .init(get: { decoded })
    }
}
