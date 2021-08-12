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

### Goal 🏁

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

### Model 💾

Requesting data to the [CityBike API](http://api.citybik.es/v2/) is completely unnecessary for this simulation (the data could just have been mocked), but it was done to try the new URLSession's async/await APIs.

Anyway, the server returns a JSON.

```json
{
    "network": {
        "company": [
            "ClearChannel"
        ],
        "href": "/v2/networks/bikemi",
        "id": "bikemi",
        "location": {
            "city": "Milano",
            "country": "IT",
            "latitude": 45.4654542,
            "longitude": 9.186516
        },
        "name": "BikeMi",
        "stations": [
            {
                "empty_slots": 28,
                "extra": {
                    "ebikes": 0,
                    "has_ebikes": true
                },
                "free_bikes": 2,
                "id": "b5262607c8a44db673b2f9acd3ddeede",
                "latitude": 45.464683238626,
                "longitude": 9.18879747390747,
                "name": "Duomo",
                "timestamp": "2021-03-04T22:58:46.228000Z"
            }
        ]
    }
}
```

###### Decodable

Three entities where decoded.

- `Station` contains info about an specific bike station.
- `Network` contains info about a company that provides the service and its bike stations.
- `City` contains info about all the networks that operate in the city.

#### Actors 🎭

Let's focus on `Station`, specifically in the properties `empty_slots` and `free_bikes`, which they are going to be modified concurrently by multiple threads.

Also, each station should handle the leave/take bike operations: checking if the operation can be done, increasing the number of free bikes and decreasing the number of empty slots atomically (and vice versa).

Swift 5.5 has introduced the concept of `actor`, a reference type that magically handles all these race conditions and atomicity.

```swift
actor Station: Decodable, Identifiable {
    var freeBikes: Int
    var emptySlots: Int

    // ...

    func addBike() {
        freeBikes += 1
        emptySlots -= 1
    }
    
    func removeBike() {
        freeBikes -= 1
        emptySlots += 1
    }
}
```
That's it, the variables (mutable state) are protected and the functions are atomic, nothing else has to be done to avoid conflicts.

Take a look to the proposal [SE-0306](https://github.com/apple/swift-evolution/blob/main/proposals/0306-actors.md) to go deeper into this concept.

### Run 🕹

Let's see how all this concepts work together and how the simulation was implemented.

###### BikeUser

This entity represents the user that wants to move around the city cycling and walking from one station to another, leaving and taking bikes.

For simplicity, just the most relevant parts of the code will be pasted here, for the complete code, check [BikeUser](https://github.com/serg-ios/concurrent-bikes/blob/main/ConcurrentBikes/Model/BikeUser.swift).

```swift
/// Each user individual simulation will return the
/// time that the user waited and the number of times
/// that it travelled by bike from one station to another.
struct SimulationResult {
    let time: TimeInterval
    let paths: Int
}

/// Identifies univocally a user.
var id: Int

/// The waiting time in nanoseconds for moving to the 
/// next station when there are not available bikes to take
/// or when there are no empty slots to leave the current bike.
private let waitingTime: UInt64 = 100_000_000

/// If `true`, the user is currently riding a bike.
private var hasBike: Bool = false

/// Runs the simulation of the user moving through the area
/// by bike, waiting to leave or take a bike when necessary.
///
/// The task can be cancelled if the user reaches the goal 
/// before going through all the paths.
///
/// - Parameters:
///
///   - stations: The array of stations that compounds 
///               the area covered by the simulation.
///
///   - paths:    The number of paths that the user 
///               must complete by bike to conclude the simulation,
///               unless it reaches its goal before.
///
///   - goal:     ID of the station the user wants to reach.
///               If `nil`, the user will run all the paths, 
///               otherwise it will run until reaches the goal.
///
/// - Returns:    The total time in seconds waited to take or leave a bike.
func runSimulation(
    in stations: [Station],
    paths: Int,
    goal: String? = nil
) async -> SimulationResult {
    var totalWaitingTime: TimeInterval = 0
    var path = 0
    while path < paths, !Task.isCancelled {
        let stationIndex = Int.random(in: 0..<stations.count)
        var station = stations[stationIndex]
        if !hasBike, await station.freeBikes > 0 {
            await takeBike(from: &station)
        } else if hasBike, await station.emptySlots > 0 {
            await leaveBike(in: &station)
            path += 1
            if await station.identifier == goal {
                withUnsafeCurrentTask { maybeUnsafeCurrentTask in
                    let task: UnsafeCurrentTask = maybeUnsafeCurrentTask!
                    task.cancel()
                }
            }
        } else {
            await wait(in: station, incrementing: &totalWaitingTime)
        }
    }
    return .init(time: totalWaitingTime, paths: path)
}

/// Waits and increments the total waiting time.
///
/// - Parameter totalWaitingTime: Reference to the accumulated time.
private func wait(
    incrementing totalWaitingTime: inout TimeInterval
) async {
    await Task.sleep(waitingTime)
    totalWaitingTime += Double(waitingTime) / 1_000_000_000
}

/// Takes a bike from a station, leaving an empty slot.
///
/// - Parameter station: The station from which the bike will be taken.
private func takeBike(from station: inout Station) async {
    await station.removeBike()
    hasBike = true
    await Task.sleep(waitingTime)
}

/// Leaves a bike in a station.
///
/// - Parameter station: The station in which the bike will be left.
private func leaveBike(in station: inout Station) async {
    await station.addBike()
    hasBike = false
    await Task.sleep(waitingTime)
}
```

The main function is `runSimulation(sations:paths:goal:)`, as it is asynchronous, it has to be marked with `async`.

###### 1. User arrives walking to the station and there available bikes.

Checking that the station has free bikes is an asynchronous operation (mutable state protected by an actor), it should be called using `await`.

A bike is removed from the station using the asynchronous and atomic method `removeBike`, the flag `hasBike` is activated.

The task goes to sleep for 0.1 seconds, simulating the travel by bike to the next station, this time is not considered waiting time because the user didn't have to wait to take the bike.

###### 2. User arrives cycling to the station and there are empty slots.

Checking that the station has empty slots is an asynchronous operation (mutable state protected by an actor), it should be called using `await`.

A bike is added to the station using the asynchronous and atomic method `addBike`, the flag `hasBike` is deactivated.

The task goes to sleep for 0.1 seconds, simulating the travel on foot to the next station, this time is not considered waiting time because the user didn't have to wait to leave its bike.

The `path` variable is incremented, reducing the number of attempts left for the user to reach its goal.

#### Task cancellation ❌

Every time the user reaches cycling a station, it is checked if this is the goal station.

If this is the case, the task is cancelled and the user will not move to the next station, the asynchronous execution will come to an end.

It is safe to obtain the task from within a function marked with `async` because that function wil always be executed as an asynchronous task.

```swift
withUnsafeCurrentTask { maybeUnsafeCurrentTask in
    let task: UnsafeCurrentTask = maybeUnsafeCurrentTask!
    task.cancel()
}
```

Before trying to move to the next station, the task has to check that is has not been cancelled.

```swift
while path < paths, !Task.isCancelled {
    // Finish the simulation when there are not more attempts available
    // or the goal has been reached and the task cancelled.
}
```

###### 3. User arrives to the station and there no bikes or slots available

In this case, the user will have to move to the next station and time will be accumulated and considered waiting time.

###### 4. Return

The function will return asynchronously a `SimulationResult` value, compounded by the total time waited by the user and the number of used attempts.

#### Simple concurrency, `async let` 🧵

Async/await functionalities are not concurrent out of the box, tasks are run asynchronously but not simultaneously.

To run concurrently few asynchronous tasks, `async let` can be used.

```swift
async let milan = try Service<City>.get(
    from: URL(string: "https://api.citybik.es/v2/networks/bikemi")!
).get()
async let madrid = try Service<City>.get(
    from: URL(string: "https://api.citybik.es/v2/networks/bicimad")!
).get()
try await print([milan?.id, madrid?.id].compactMap({$0}).joined(separator: " "))

```

The thread will not pause after each asynchronous operation as usual (note that they are not marked with `await`), `async let` constants will be calculated on background until they are used. At that point the execution must pause until all the needed values are ready, in this case, that happens in `try await print([milan?.id, madrid?.id].compactMap({$0}).joined(separator: " "))`. Once both values are obtained, the thread is resumed and that line is executed.

#### Complex concurrency, `TaskGroup` 🧶

Is very easy to use `async let` when the number of concurrent tasks is reduced. But what happens when there are 30 or 40 tasks? In that case, `async let` is not a scalable solution.

```swift
for user in bikeUsers {
    let _ = await user.runSimulation(in: station, paths: 60)
    // With this approach, the next user will run its simulation
    // when the previous one finishes. The thread will pause and
    // resume as soon as the async function ends its execution.
}
```

When several tasks are going to be executed concurrently (maybe in a `for` loop), another approach is necessary. The code below has been filtered for simplicity, for more details, check [BikeUserTests](https://github.com/serg-ios/concurrent-bikes/blob/main/ConcurrentBikesTests/Model/BikeUserTests.swift).

```swift
await withTaskGroup(of: BikeUser.SimulationResult.self) { group in
    for bikeUser in bikeUsers {
        group.addTask {
            return await bikeUser.runSimulation(in: stations, paths: attempts)
        }
    }
    for await simulationResult in group {
        totalWaitedTime += simulationResult.time
        totalPathsRun += simulationResult.paths
    }
}
```

<!--
	This feature is evolving.
	Xcode 13 beta 4 was used.
    Test functions must be marked as async.
-->






















