//
//  URLSession+AsyncData.swift
//  ConcurrentBikes
//
//  Created by Alberto Caamano Souto on 15/12/21.
//

import Foundation

// Nothing fancy here, only a function to mimic the built-in iOS 15 one.
// https://www.swiftbysundell.com/articles/making-async-system-apis-backward-compatible/
@available(iOS, deprecated: 15.0, message: "Use the built-in API instead")
extension URLSession {
    func data(from url: URL) async throws -> (Data, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            let task = self.dataTask(with: url) { data, response, error in
                guard let data = data, let response = response else {
                    let error = error ?? URLError(.badServerResponse)
                    return continuation.resume(throwing: error)
                }

                continuation.resume(returning: (data, response))
            }

            task.resume()
        }
    }
}
