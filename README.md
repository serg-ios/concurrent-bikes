# Concurrent Bikes

The aim of this project is to test the new async/await and concurrency features introduced in Swift 5.5.

## CityBike 🌎

Real time information about bike stations in cities all around the world can be requested for free thanks to [CityBike API](http://api.citybik.es/v2/).

## Simulation 🤖

This iOS project will simulate how a certain number of bicycle users travel by bike across the city, from one bike station to another.

### Arrives to a station walking 👣

At the beginning of the simulation, no user has a bike so they all have to go (walking) to a station to collect one.

###### Possible scenarios

✅ There are bikes available. So it takes the bike and moves to the next station to leave it.

⛔️ There are no bikes available in this station. So it moves to the next station (walking) to see if there are available bikes there.

### Arrives to a station by bike 🚲

When the user arrives to a station by bike, it has to leave it so that others can use it.

###### Possible scenarios

✅ There are empty slots. So it can leave the bike and move walking to the next station.

⛔️ There are no empty slots in this station. So it moves to the next station (cycling) to see if there are empty slots there.

### Goal and attempts 🏁

A goal station can be set for an user and a maximum number of attempts to reach its target (leave a bike in this station).

If the goal is reached, the simulation finishes for that user, otherwise, it will continue until the maximum number of attempts is reached.

The number of attempts is increased everytime the user arrives cycling to a station (arriving on foot doesn't count) and there is an empty space so it can leave its bike.

### Time ⏳

Moving from one station to another takes time and this time will have a different consideration depending on the user's activity.

###### Waiting time

When the user has to move to another station because there are not bikes available to take or (if it already has a bike) there are no empty spaces to leave its bike, this will be considered waiting time.

###### Normal time

When the user is moving walking or cycling to a station to leave or take a bike (not because it could not do this in the previous station), this will be considered normal time.

### Randomness 🎲

The next station will always be chosen randomly. In fact, the next station can be the station in which the user already is and the time to reach any station (even the one in which the user already is) is always the same.

The aim of this project is not to create a great and realistic simulation, its only purpose is to generate a simple situation to which the new async/await and concurrency features can be applied.

## Concurrency 🧵

This would not be funny with only one user travelling through the city, this is why multiple users will run their individual simulations simultaneously, using the same stations, fighting to take bikes and to find empty slots.

###### No conflict

In a simulation with only one station and more bikes than users, there will never be conflicts. Because the station will always have a bike or an empty space to offer.

###### Conflict

Two or more users arrive walking or cycling to a station with not enough bikes or empty slots for everybody, some will have to move to the next station (waiting time for that users).

### Race conditions 🏎

Users cannot communicate to each other, they can only communicate with the station and this will tell them if they can take/leave a bike, or if they will have to try their luck in the next station.

So its impossible for them to reach an agreement and pass the bicycle to each other without having to park it and pick it up.

The station will handle this transaction, in which the order of arrival matters little, the bike or empty slot may be conferred to a newcomer rather than to an user that has been waiting for an hour.

In order to the number of free bikes and empty slots to remain consistent, all the take bike / leave bike operations for each user must be done atomically.

###### Take bike atomic operation

Check if there is any free bike and if there is, decrement the number of free bikes in the station and increment the number of empty slots in the station.

###### Leave bike atomic operation

Check if there is any empty slot and if there is, decrement the number of empty slots in the station and increment the number of free bikes in the station.

#### What could happen without atomicity? ⚛️

Two users (A and B) could arrive cycling to a station with only one empty slot and both would want to leave their bikes.

As every user is independent from each other, without atomicity, the sequence of events could be as follows:

1. User A asks the station if it has empty slots available. 
2. The station says yes.
3. User B asks the station if it has empty slots available.
4. The station says yes.
5. The station's number of slots available drops down to 0 due to user B.
6. The station's number of slots available drops down again to -1 due to user A.

There can not be -1 empty slots, this is an incorrect state for the bike station and to avoid it, events 1, 2 and 6 should not have been interspersed with events 3, 4 and 5.

Note that the user A asks first to the station but the station answers first to B. This has been done on purpose to emphasize that the order of arrival doesn't matter to the station.

## Implementation ⚒️

Async/await and structured concurrency features have been applied to all the steps of the development: service, model, mocking, testing and of course the simulation itself.

### Data collection 📡

Realistic data about bike stations can be obtained from [CityBike API](http://api.citybik.es/v2/) but it can also be mocked to make testing easier, faster and more reliable.

###### Protocol witness 

In fact, the app doesn't care where the data comes from, its a great idea using a protocol witness to abstract data collection leveraging all the power of generics.

```swift
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
```

In the `get(from url: URL)` function and the protocol witness' closure `let get: () async -> T?`, the first outbreaks of async/await can be seen.

Thanks to generics, this protocol witness can be reused to collect asynchronously any kind of `Decodable` data from different sources.

```swift
// Obtains whatever decodable object from an URL.
let whateverDecodable = try await Service<WhateverDecodable>.get(from: url).get()
```

```swift
// Obtains whatever decodable object from a JSON file.
let whateverDecodable = try await Service<WhateverDecodable>.get(
	from: "JsonNameWithoutExtension",
	bundle: bundle
).get()
```

#### URLSession's async/await APIs 🌐

The typical approach of data fetching with `URLSession` is using completion handlers.

```swift
URLSession.shared.dataTask(with: url) { data, response, error in
	// Code here will run when the async operation finishes.
}
```

This solution adds an undesirable identation level for each data task. If there are more requests to be made after the first one and each one depends on the result of its predecessor, they would have to be put one inside the other and the result would be cumbersome with so many unpleasant identation levels.

```swift
URLSession.shared.dataTask(with: url) { _, _, _ in
	URLSession.shared.dataTask(with: url) { _, _, _ in
		URLSession.shared.dataTask(with: url) { _, _, _ in
			URLSession.shared.dataTask(with: url) { _, _, _ in
				// Code here will run when all the async operations finish.
				// ...

```

###### Async/await 

With the async/await approach, the code is run sequentially without the need of identation. When `let (data, _) = try await URLSession.shared.data(from: url)` is executed, the thread is paused and it will resume its execution in the next line when the async operation finishes.

The data will be available when the execution is resumed, in this case the response is not interesting so it is omitted with an `_` and the error is not collected but thrown if required.

Note that asynchronous functions can only be called from asynchorous contexts, so the method must be marked as `async`. As a consequence, the closure from the protocol witness has to be marked as asynchronous as well.

#### Test async/await functions 🚨

To test asynchronous code, [XCTestExpectation](https://developer.apple.com/documentation/xctest/xctestexpectation) is not needed anymore.

```swift
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

    func testGetFromJson() async {
        do {
            let city = try await Service<City>.get(from: "Milano", bundle: bundle).get()
            XCTAssertEqual(city?.id, "bikemi")
        } catch {
            handleError(error)
        }
    }
```

The test method will be paused while the asynchronous operation is running and it will resume when it finishes, whereupon the assertion will be executed as if nothing had happened.


<!--
	This feature is evolving.
	Xcode 13 beta 4 was used.
	Model section before data collection.
-->






















