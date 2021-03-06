//
//  ServiceTests.swift
//  ConcurrentBikesTests
//
//  Created by Sergio Rodríguez Rama on 17/7/21.
//

import XCTest

@testable import ConcurrentBikes

class ServiceTests: XCTestCase {
    
    private let bundle = Bundle(for: ServiceTests.self)
    
    // MARK: - URLSession
    
    func testGetFromURL() async {
        guard let url = URL(string: "https://api.citybik.es/v2/networks/bikemi") else {
            XCTFail("Invalid URL.")
            return
        }
        do {
            let city = try await Service<City>.get(from: url).get()
            XCTAssertEqual("bikemi", city?.id)
        } catch {
            handleError(error)
        }
    }
    
    func testGetDecodingErrorThrown() async {
        guard let url = URL(string: "https://api.citybik.es/v2/networks/bikemi") else {
            XCTFail("Invalid URL.")
            return
        }
        do {
            let _ = try await Service<Network>.get(from: url).get()
            XCTFail("Error should be thrown.")
        } catch {
            XCTAssertNotNil(error as? DecodingError)
        }
    }
    
    // MARK: - Error
    
    func testMissingFileErrorThrown() async {
        do {
            async let _ = try await Service<City>.get(from: "Madrid", bundle: bundle).get()
        } catch {
            let expectedError = ServiceError.missingFile("Madrid.json")
            XCTAssertEqual(error as? ServiceError, expectedError)
        }
    }
    
    func testDecodingErrorThrown() async {
        let fileName = "InvalidJson"
        do {
            async let _ = try await Service<City>.get(from: fileName, bundle: bundle).get()
        } catch {
            XCTAssertNotNil(error as? DecodingError)
        }
    }
}
