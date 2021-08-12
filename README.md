# Concurrent Bikes

This project aims to test the new async/await and concurrency features introduced in Swift 5.5.

Take into consideration that these features are evolving. In fact, during the development of this project, a few problems were found and solved by downloading the latest Xcode 13 beta 4.

All the code is available [here](https://github.com/serg-ios/concurrent-bikes).

## CityBike 🌎

Request real-time information about bike stations in cities worldwide for free, thanks to [CityBike API](http://api.citybik.es/v2/).

## Simulation 🤖

This iOS project will simulate how many bicycle users travel across the city from one bike station to another.

### Arrives at a station walking 👣

At the beginning of the simulation, no user has a bike, so they all have to go (walking) to a station to collect one.

###### Possible scenarios

✅ There are bikes available. So it takes the bike and moves to the next station to leave it.

⛔️ There are no bikes available in this station. So it moves to the next station (walking) to see if there are available bikes there.

### Arrives at a station by bike 🚲

When the user arrives at a station by bike, it has to leave it so that others can use it.

###### Possible scenarios

✅ There are empty slots. So it can leave the bike and move walking to the next station.

⛔️ There are no empty slots in this station. So it moves to the next station (cycling) to see if there are empty slots there.

### Goal 🏁

A goal station can be set for a user and a maximum number of attempts to reach its target (leave a bike in this station).

When a user reaches its goal, the simulation finishes for it. Otherwise, it will continue until it reaches the maximum number of attempts.

The number of attempts increases every time the user arrives cycling to a station (arriving on foot does not count), and there is space to leave its bike.

### Time ⏳

Moving from one station to another takes time, and this time will have a different consideration depending on the user's activity.

###### Waiting time

When the user has to move to another station because there are no bikes available to take or (if it already has a bike) there are no empty spaces to leave its bike, this will be considered waiting time.

###### Normal time

When the user moves walking or cycling to a station to leave or take a bike (not because it could not do this in the previous station), this will be considered standard time.

### Randomness 🎲

The next station will always be chosen randomly, and it can be the station the user already is.

The time to reach any station (even where the user already is) is always the same.

This project aims not to create a great and realistic simulation, its only purpose is to generate a simple situation to which the new async/await, and concurrency features can be applied.

## Concurrency 🧵

It would not be funny with only one user traveling through the city, and this is why multiple users will run their simulations simultaneously, using the same stations, fighting to take bikes, and finding empty slots.

###### No conflict

There will never be conflicts in a simulation with only one station and more bikes than users because the station will always have a bike or a space to offer.

###### Conflict

Two or more users arrive walking or cycling to a station with not enough bikes or empty slots for everybody, and some will have to move to the next station (waiting time for that users).

### Race conditions 🏎

Users cannot communicate with each other. They can only communicate with the station, which will tell them if they can take/leave a bike or try their luck in the next station.

So they cannot reach an agreement and pass the bicycle to each other without parking it and picking it up.

The station will handle this transaction, in which the order of arrival matters little. The bike or empty slot may be conferred to a newcomer rather than a user waiting for an hour.

For the number of free bikes and empty slots to remain consistent, each user's take/leave bike operations must be atomic.

###### Take bike atomic operation

Check if there is any free bike and if there is, decrement the number of free bikes in the station and increment the number of empty slots in the station.

###### Leave bike atomic operation

Check if there is an empty slot and if there is, decrement the number of empty slots in the station and increment the number of free bikes in the station.

#### What could happen without atomicity? ⚛️

Two users (A and B) could arrive cycling to a station with only one empty slot, and both would want to leave their bikes.

As every user is independent of each other, without atomicity, the sequence of events could be as follows:

1. User A asks the station if it has empty slots available. 
2. The station says yes.
3. User B asks the station if it has empty slots available.
4. The station says yes.
5. The station's number of slots available drops down to 0 due to user B.
6. The station's number of slots available drops down again to -1 due to user A.

There can not be -1 empty slots; it is an incorrect state for the bike station. Events 1, 2, and 6 should not have been interspersed with events 3, 4, and 5.

User A asks first the station, but the station answers first to B; this has been done on purpose to emphasize that the order of arrival does not matter to the station.

## Implementation ⚒️

Async/await and structured concurrency features have been applied to all the steps of the development: service, model, mocking, testing, and of course, the simulation itself.

### Data collection 📡

Realistic data about bike stations can be obtained from [CityBike API](http://api.citybik.es/v2/) but can also be mocked to make testing more accessible and faster.

###### Protocol witness 

The app does not care where the data comes from, and it is a great idea to use a protocol witness to abstract data collection leveraging all the power of generics.

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

Thanks to generics, this protocol witness can be reused to collect any `Decodable` data from different sources asynchronously.

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

This solution adds an undesirable indentation level for each data task. If there are more requests to be made after the first one and each one depends on the result of its predecessor, they would have to be put one inside the other, and the result would be cumbersome with so many unpleasant indentation levels.

```swift
URLSession.shared.dataTask(with: url) { _, _, _ in
    URLSession.shared.dataTask(with: url) { _, _, _ in
        URLSession.shared.dataTask(with: url) { _, _, _ in
            URLSession.shared.dataTask(with: url) { _, _, _ in
                // Code here will run when all the async operations finish.
                // ...

```

###### Async/await 

With the async/await approach, the code is run sequentially without the need for indentation. When `let (data, _) = try await URLSession.shared.data(from: url)` is executed, the thread pauses, and it resumes its execution in the next line when the async operation finishes.

The data will be available when the execution resumes; in this case, the response is not attractive, so it is omitted with an `_`, and the error is not collected but thrown if required.

Note that asynchronous functions can only be called from asynchronous contexts, so the method must be marked as `async`. As a consequence, the closure from the protocol witness has to be marked as asynchronous as well.

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

The test method will pause while the asynchronous operation is running, and it will resume when it finishes, at which point the assertion will execute as if nothing had happened.

### Model 💾

Requesting data to the [CityBike API](http://api.citybik.es/v2/) is entirely unnecessary for this simulation (the data could just have been mocked), but it was done to try the new URLSession's async/await APIs.

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

Three entities were decoded.

- `Station` contains info about a specific bike station.
- `Network` contains info about a company that provides the service and its bike stations.
- `City` contains info about all the networks that operate in the city.

#### Actors 🎭

Let us focus on `Station`, specifically in the properties `empty_slots` and `free_bikes`, which multiple threads will modify concurrently.

Also, each station should handle the leave/take bike operations: checking if the operation can be done, increasing the number of free bikes, and decreasing the number of empty slots atomically (and vice versa).

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
The variables (mutable state) are protected, and the functions are atomic; nothing else must be done to avoid conflicts.

### Run 🕹

Let us see how all these concepts work together and how the simulation runs.

###### BikeUser

This entity represents the user that wants to move around the city, cycling and walking from one station to another, leaving and taking bikes.

For simplicity, just the most relevant parts of the code will be posted here; for the complete code, check [BikeUser](https://github.com/serg-ios/concurrent-bikes/blob/main/ConcurrentBikes/Model/BikeUser.swift).

```swift
/// Each user simulation will return the
/// time that it waited and the number of times
/// that it traveled by bike from one station to another.
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

/// Simulates the user moving through the area
/// by bike, waiting to leave or take a bike when necessary.
///
/// The task can be canceled if the user reaches the goal 
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
///               otherwise, it will run until it reaches the goal.
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

The primary function is `runSimulation(stations:paths:goal:)`, as it is asynchronous, it must be marked with `async`.

###### 1. The user arrives walking to the station, and there are available bikes.

Checking that the station has free bikes is an asynchronous operation (mutable state protected by an actor); it should be called using `await`.

A bike is removed from the station using the asynchronous and atomic method `removeBike`, the flag `hasBike` is activated.

The task goes to sleep for 0.1 seconds, simulating the travel by bike to the next station; this time is not considered waiting time because the user did not have to wait to take the bike.

###### 2. The user arrives cycling to the station, and there are empty slots.

Checking that the station has empty slots is an asynchronous operation (mutable state protected by an actor); it should be called using `await`.

A bike is added to the station using the asynchronous and atomic method `addBike`, the flag `hasBike` is deactivated.

The task goes to sleep for 0.1 seconds, simulating the travel on foot to the next station; this time is not considered waiting time because the user did not have to wait to leave the bike.

The `path` variable increments and reduces the number of attempts left for the user to reach its goal.

#### Task cancellation ❌

Every time the user reaches cycling a station, it checks if this is the goal station.

If this is the case, the task is canceled, and the user will not move to the next station, the asynchronous execution will end.

It is safe to obtain the task from within a function marked with `async` because that function will always be executed as an asynchronous task.

```swift
withUnsafeCurrentTask { maybeUnsafeCurrentTask in
    let task: UnsafeCurrentTask = maybeUnsafeCurrentTask!
    task.cancel()
}
```

Before moving to the next station, the task has to check that it has not been canceled.

```swift
while path < paths, !Task.isCancelled {
    // Finish the simulation when there are not more attempts available
    // or the goal has been reached, and the task canceled.
}
```

###### 3. The user arrives at the station, and there are no bikes or slots available

In this case, the user will have to move to the next station, and time will be accumulated and considered waiting time.

###### 4. Return

The function will return a `SimulationResult` value asynchronously, compounded by the total time waited by the user and the number of user attempts.

#### Simple concurrency, `async let` 🧵

Async/await functionalities are not concurrent out of the box. Tasks are run asynchronously but not simultaneously.

To run a few asynchronous tasks concurrently, `async let` can be used.

```swift
async let milan = try Service<City>.get(
    from: URL(string: "https://api.citybik.es/v2/networks/bikemi")!
).get()
async let madrid = try Service<City>.get(
    from: URL(string: "https://api.citybik.es/v2/networks/bicimad")!
).get()
try await print([milan?.id, madrid?.id].compactMap({$0}).joined(separator: " "))

```

The thread will not pause after each asynchronous operation as usual (note that they are not marked with `await`), `async let` constants will be calculated on the background until they are used. At that point the execution must pause until all the needed values are ready, in this case, that happens in `try await print([milan?.id, madrid?.id].compactMap({$0}).joined(separator: " "))`. Once both values are obtained, the thread resumes and executes that line.

#### Complex concurrency, `TaskGroup` 🧶

It is effortless to use `async let` when the number of concurrent tasks is small. Nevertheless, what happens when there are 30 or 40 tasks? In that case, `async let` is not a scalable solution.

```swift
for user in bikeUsers {
    let _ = await user.runSimulation(in: station, paths: 60)
    // With this approach, the next user will run its simulation
    // when the previous one finishes. The thread will pause and
    // resume as soon as the async function ends its execution.
}
```

When several tasks are going to be executed concurrently (maybe in a `for` loop), another approach is necessary. The code below has been summarized for simplicity. For more details, check [BikeUserTests](https://github.com/serg-ios/concurrent-bikes/blob/main/ConcurrentBikesTests/Model/BikeUserTests.swift).

```swift
// Total time waited by all users must be greater than zero 
// because there are more users than bikes.
var totalWaitedTime: TimeInterval = 0
// Total number of paths run by all the users during the simulation.
var totalPathsRun = 0
// TaskGroup creation.
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

Many tasks that will run concurrently compound a task group. The asynchronous method `withTaskGroup` receives the type that the tasks will return and initializes the group. This type can be `Void.self` if the tasks that compound the group do not return any value.

Calling the method `addTask`, a task is added to the group. This method receives a closure that returns the asynchronous result of a task that will run concurrently.

By doing this inside a `for` loop, many tasks can be added to the group and executed concurrently.

###### AsyncSequence

The results will arrive in drips and drabs, and the task group will not conclude its execution until all the tasks have finished and all the results have been collected. If the type of the task group is `Void.self`, there will be no results to collect.

As `TaskGroup` implements the `AsyncSequence` protocol, the results can be accessed with a `for await` loop. In each iteration, the execution will pause until a result is ready to collect, and after doing something with the collected value, the execution will pause again to wait for the next concurrent asynchronous task of the group to finish until all the tasks of the group complete.

## Conclusions 🎬

These examples are just the tip of the iceberg. Check the proposals to learn more.

- Async/await [SE-0296](https://github.com/apple/swift-evolution/blob/main/proposals/0296-async-await.md).
- Structured concurrency [SE-0304](https://github.com/apple/swift-evolution/blob/main/proposals/0304-structured-concurrency.md).
- Actors [SE-0306](https://github.com/apple/swift-evolution/blob/main/proposals/0306-actors.md).
