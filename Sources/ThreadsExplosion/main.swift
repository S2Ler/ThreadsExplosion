import Foundation

let N = 200 // Number of threads to explode to

// Create N number of serial queues without a target.
// Serial queues without a target queue target global overcommit concurrent queues.
// That means that each block submitted to such queue will create a thread if there is no one available already.
var serialQueues: [DispatchQueue] = []

print("Creating \(N) serial queues")
for i in 0..<N {
  serialQueues.append(.init(label: "SerialQueue\(i)"))
  // Replace the line above with the line below to fix threads explosion above GCD limit. 
  //  serialQueues.append(.init(label: "SerialQueue\(i)", target: .global()))
}

print("Dispatching \(N) long tasks for each serial queue")
for i in 0..<N {
  serialQueues[i].async {
    Thread.sleep(until: .distantFuture)
  }
}


// Give GCD some time to create enough threads.
let waitTime: TimeInterval = 3.0
print("Waiting \(waitTime) seconds.")
// Print Number of created threads.
DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
  do {
    print("Number of threads: \(try threadsCount())")
  }
  catch {
    print("Error getting threads count: \(error)")
  }
}

RunLoop.current.run(until: .distantFuture)
