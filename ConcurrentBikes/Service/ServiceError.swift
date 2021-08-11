//
//  ServiceError.swift
//  ConcurrentBikes
//
//  Created by Sergio Rodríguez Rama on 17/7/21.
//

import Foundation

/// Errors that can be thrown during data collection using `Service` protocol witness.
enum ServiceError: Error {
    case missingFile(_ fileName: String)
}

extension ServiceError: Equatable {
    static func ==(lhs: ServiceError, rhs: ServiceError) -> Bool {
        switch (lhs, rhs) {
        case (.missingFile(let lhsFile), .missingFile(let rhsFile)):
            return lhsFile == rhsFile
        }
    }
}
