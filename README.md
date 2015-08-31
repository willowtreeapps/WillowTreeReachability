# WTReachability

Simple Swift class for monitoring network reachability. This class uses a closure to notify listeners of network status changes. Multiple listeners may be added to a single Reachability instance.

## Usage

To start Reachability, begin by initializing the class to check for either host reachability or general reachability as shown below:

```swift
// Reachability for specific host
let reachability = Reachability(withURL: NSURL(string: "http://www.willowtreeapps.com")!)

// General internet Reachability
let reachability = Reachability()
```

Please note that WTReachability uses optional initializers and if there is an error creating the reachability connection, then nil is returned.

### Asynchronous Notifications

WTReachability utilizes asynchronous network status monitoring to update the application of network changes. The notifier can be started by calling ```startNotifier``` and adding a callback through the ```addReachabilityCallback``` function. An example is shown below.

```
reachability?.startNotifier()

reachability?.addReachabilityCallback(withIdentifier: "Callback") { (status: ReachabilityStatus) in
    print("Reachabilty status is \(status)")
}
```

### Stopping Reachability

In order to properly clean up when stopping the reachability notifications, the ```stopNotifier``` function should be called.
