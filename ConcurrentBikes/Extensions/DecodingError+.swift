//
//  DecodingError+.swift
//  ConcurrentBikes
//
//  Created by Sergio Rodríguez Rama on 17/7/21.
//

import Foundation

extension DecodingError {
    public var errorDescription: String? {
        switch self {
        case .typeMismatch(_, let context):
            return "\(context)"
        case .keyNotFound(let key, _):
            return "\(key)"
        default:
            return "\(localizedDescription)"
        }
    }
}

