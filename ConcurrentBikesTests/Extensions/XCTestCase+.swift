//
//  XCTestCase+.swift
//  ConcurrentBikesTests
//
//  Created by Sergio Rodríguez Rama on 17/7/21.
//

import Foundation
import XCTest

extension XCTestCase {
    func handleError(_ error: Error) {
        if let decodingErrorDescription = (error as? DecodingError)?.errorDescription {
            XCTFail(decodingErrorDescription)
        } else {
            XCTFail(error.localizedDescription)
        }
    }
}
