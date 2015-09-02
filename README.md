# WillowTreeReachability

Simple Swift class for monitoring network reachability. This class uses a subscription model to notify listeners of network status changes. Multiple listeners may be added to a single Reachability instance.

## Usage

To start Reachability, begin by initializing the class to check for either host reachability or general reachability as shown below:

```swift
import WillowTreeReachability

// Reachability for specific host
let reachability = Monitor(withURL: NSURL(string: "http://www.willowtreeapps.com")!)

// General internet Reachability
let reachability = Monitor()
```

Please note that WillowTreeReachability uses optional initializers and if there is an error creating the reachability connection, then nil is returned.

### Asynchronous Notifications

WillowTreeReachability utilizes asynchronous network status monitoring to update the application of network changes. The notifier can be started by calling ```startMonitoring``` and adding a subscriber through the ```addReachabilitySubscriber``` function. An example is shown below.

```
reachability?.startMonitoring()

self.reachabilitySubscription = self.reachability?.addReachabilitySubscriber(self)

}
```

The subscription should be held strongly by the callee to keep the subscription active.

### Stopping Reachability

In order to properly clean up when stopping the reachability notifications, the ```stopMonitoring``` function should be called.
