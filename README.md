# ThreadsExplosion

A sample app to demonstrate how incorrect usage of serial DispatchQueue with default target queue can lead to thread explosion
above GCDs non-overcommit queues limits.

### Quote from [maillist](https://lists.macosforge.org/pipermail/libdispatch-dev/2011-June/000552.html)

> For items/queues submitted to an overcommit global queue, the current Mac OS X kernel workqueue mechanism creates threads
> more eagerly, e.g. even if an n-wide machine is already fully committed with n cpu-busy threads, submitting another item directly
> to the overcommit global queue or indirectly to a serial queue with default target queue will cause another thread to be created to
> handle that item (potentially overcommitting the machine, hence the name).

> If you wish to avoid this, simply set the target queue of your serial queues to the default priority global queue (i.e. non-overcommit).

> The overcommit/non-overcommit distinction is intentionally undocumented and only available in the queue_private.h header
> because we hope to revise the kernel workqueue mechanism in the future to avoid the need for this distinction.

More tips from [here](https://gist.github.com/tclementdev/6af616354912b0347cdf6db159c37057):

# libdispatch efficiency tips

I suspect most developers are using the libdispatch inefficiently due to the way it was presented to us at the time it was introduced and for many years after that, and due to the confusing documentation and API. I realized this after reading the 'concurrency' discussion on the swift-evolution mailing-list, in particular the messages from Pierre Habouzit (who is the libdispatch maintainer at Apple) are quite enlightening (and you can also find many tweets from him on the subject).

* https://lists.swift.org/pipermail/swift-evolution/Week-of-Mon-20170828/date.html
* https://lists.swift.org/pipermail/swift-evolution/Week-of-Mon-20170904/date.html
* https://twitter.com/pedantcoder

My take-aways are:

* You should have very few, well-defined queues. If all these queues are active at once, you will get as many threads running. These queues should be seen as execution contexts in the program (gui, storage, background work, ...) that benefit from executing in parallel.

* Go serial first, and as you find performance bottle necks, measure why, and if concurrency helps, apply with care, always validating under system pressure. Reuse queues by default and add more if there's some measurable benefit to it. In most apps, you probably should not use more than 3 or 4 queues.

* Queues that target other (non-global) queues are fine, these are the ones which scale.

* Don't use `dispatch_get_global_queue()`. It doesn't play nice with qos/priorities and can lead to thread explosion. Run your code on one of your execution context instead.

* `dispatch_async()` is wasteful if the dispatched block is small (< 1ms), as it will most likely require a new thread due to libdispatch's overcommit behavior. Prefer locking to protect shared state (rather than switching the execution context).

* Some classes/libraries are better designed as reusing the execution context from their callers/clients. That means using traditional locking for thread-safety. `os_unfair_lock` is usually the fastest lock on the system (nicer with priorities, less context switches).

* If running concurrently, your work items need not to contend, else your performance sinks dramatically. Contention takes many forms. Locks are obvious, but it really means use of shared resources that can be a bottle neck: IPC/daemons, malloc (lock), shared memory, I/O, ...

* You don't need to be async all the way to avoid thread explosion. Using a limited number of bottom queues and not using `dispatch_get_global_queue()` is a better fix.

* The complexity (and bugs) of heavy async/callback designs also cannot be ignored. Synchronous code remains much easier to read, write and maintain.

* Concurrent queues are not as optimized as serial queues. Use them if you measure a performance improvement, otherwise it's likely premature optimization.

* Use `dispatch_async_and_wait()` instead of `dispatch_sync()` if you need to mix async and sync calls on the same queue. `dispatch_async_and_wait()` does not guarantee execution on the caller thread which allows to reduce context switches when the target queue is active.

* Utilizing more than 3-4 cores isn't something that is easy, most people who try actually do not scale and waste energy for a modicum performance win. It doesn't help that CPUs have thermal issues if you ramp up, e.g. Intel will turn off turbo-boost if you use enough cores.

* Measure the real-world performance of your product to make sure you are actually making it faster and not slower. Be very careful with micro benchmarks (they hide cache effects and keep thread pools hot), you should always have a macro benchmark to validate what you're doing.

* libdispatch is efficient but not magic. Resources are not infinite. You cannot ignore the reality of the underlying operating system and hardware you're running on. Not all code is prone to parallelization.

Look at all the `dispatch_async()` calls in your code and ask yourself whether the work you're dispatching is worth switching to a different execution context. Most of the time, locking is probably the better choice.

Once you start to have well defined queues (execution contexts) and to reuse them, you may run into deadlocks if you `dispatch_sync()` to them. This usually happens when queues are used for thread-safety, again the solution is locking instead and using `dispatch_async()` only when you need to switch to another execution context.

I've personally seen *massive* performance improvements by following these recommandations (on a high throughput program). It's a new way of doing things but it's worth it.


[@tclementdev](https://twitter.com/tclementdev/)

## More Links

Use very few queues

* https://lists.swift.org/pipermail/swift-evolution/Week-of-Mon-20170828/039368.html
* https://lists.swift.org/pipermail/swift-evolution/Week-of-Mon-20170828/039405.html
* https://lists.swift.org/pipermail/swift-evolution/Week-of-Mon-20170828/039410.html
* https://lists.swift.org/pipermail/swift-evolution/Week-of-Mon-20170828/039420.html
* https://lists.swift.org/pipermail/swift-evolution/Week-of-Mon-20170828/039429.html
* https://lists.swift.org/pipermail/swift-evolution/Week-of-Mon-20170904/039461.html

Go serial first

* https://twitter.com/pedantcoder/status/1081658384577835009
* https://twitter.com/pedantcoder/status/1081659784841969665
* https://twitter.com/pedantcoder/status/904839926180569089
* https://twitter.com/pedantcoder/status/904840156330344449
* https://twitter.com/Catfish_Man/status/1081581652147490817

Don't use global queues

* https://twitter.com/pedantcoder/status/773903697474486273
* https://lists.swift.org/pipermail/swift-evolution/Week-of-Mon-20170828/039368.html

Beware of concurrent queues

* https://twitter.com/pedantcoder/status/960915209584914432
* https://twitter.com/pedantcoder/status/960916427833163776

Don't use async to protect shared state

* https://twitter.com/pedantcoder/status/820473404440489984
* https://twitter.com/pedantcoder/status/820473580819337219
* https://twitter.com/pedantcoder/status/820740434645221376
* https://twitter.com/pedantcoder/status/904467942208823296
* https://twitter.com/pedantcoder/status/904468363149099008
* https://twitter.com/pedantcoder/status/820473711606124544
* https://twitter.com/pedantcoder/status/820473923527589888

Don't use async for small tasks

* https://twitter.com/pedantcoder/status/1081657739451891713
* https://twitter.com/pedantcoder/status/1081642189048840192
* https://twitter.com/pedantcoder/status/1081642631732457472
* https://twitter.com/pedantcoder/status/1081648778975707136

Some classes/libraries should just be synchronous

* https://lists.swift.org/pipermail/swift-evolution/Week-of-Mon-20170904/039461.html

Contention is a performance killer for concurrency

* https://twitter.com/pedantcoder/status/1081657739451891713
* https://twitter.com/pedantcoder/status/1081658172610293760

To avoid deadlocks, use locks to protect shared state

* https://twitter.com/pedantcoder/status/744269824079998977
* https://twitter.com/pedantcoder/status/744269947723866112

Don't use semaphores to wait for asynchronous work

* https://twitter.com/pedantcoder/status/1175062243806863360
* https://lists.swift.org/pipermail/swift-evolution/Week-of-Mon-20170828/039405.html

The NSOperation API has some serious performance pitfalls

* https://twitter.com/pedantcoder/status/1082097847653154817
* https://twitter.com/pedantcoder/status/1082111968700289026
* https://twitter.com/Catfish_Man/status/1082097921632264192
* https://lists.swift.org/pipermail/swift-evolution/Week-of-Mon-20170828/039415.html

Avoid micro-benchmarking

* https://twitter.com/pedantcoder/status/1081660679054999552
* https://twitter.com/Catfish_Man/status/1081673457182490624

Resources are not infinite

* https://twitter.com/pedantcoder/status/1081661310771712001
* https://lists.swift.org/pipermail/swift-evolution/Week-of-Mon-20170828/039410.html
* https://lists.swift.org/pipermail/swift-evolution/Week-of-Mon-20170828/039429.html

Background QOS work is paused when low-power mode is enabled

* https://twitter.com/gregheo/status/1001501337907970048?s=12

About `dispatch_async_and_wait()`

* https://twitter.com/pedantcoder/status/1135938715098857477

Utilizing more than 3-4 cores isn't something that is easy

* https://twitter.com/pedantcoder/status/1140041360868704256

A lot of iOS 12 perf wins were from daemons going single-threaded

* https://twitter.com/Catfish_Man/status/1081673457182490624
* https://twitter.com/Catfish_Man/status/1081590712376774661
