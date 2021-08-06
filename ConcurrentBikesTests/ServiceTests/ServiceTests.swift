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
    
    func testGetSuccess() async {
        guard let url = URL(string: "https://api.citybik.es/v2/networks/bikemi") else {
            XCTFail("Invalid URL.")
            return
        }
        do {
            let city = try await Service<City>.get(from: url).get()
            XCTAssertEqual("bikemi", city?.network.id)
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
            let network = try await Service<Network>.get(from: url).get()
            XCTAssertEqual("bikemi", network?.id)
        } catch {
            XCTAssertNotNil(error as? DecodingError)
        }
    }
    
    // MARK: - Error
    
    func testMissingFileErrorThrown() async {
        do {
            async let _ = try await Service<City>.json(fileName: "Madrid", bundle: bundle).get()
        } catch {
            let expectedError = ServiceError.missingFile("Madrid.json")
            XCTAssertEqual(error as? ServiceError, expectedError)
        }
    }
    
    func testDecodingErrorThrown() async {
        let fileName = "InvalidJson"
        do {
            async let _ = try await Service<City>.json(fileName: fileName, bundle: bundle).get()
        } catch {
            XCTAssertNotNil(error as? DecodingError)
        }
    }
}
