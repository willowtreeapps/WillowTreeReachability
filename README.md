[![Build Status](https://travis-ci.org/willowtreeapps/WillowTreeReachability.svg?branch=master)](https://travis-ci.org/willowtreeapps/WillowTreeReachability?branch=master)

# WillowTreeReachability
by [WillowTree, Inc.](http://www.willowtreeapps.com) *We're hiring! Come join our team!*

Simple Swift class for monitoring network reachability. This class uses a subscription model to notify listeners of network status changes. Multiple listeners may be added to a single Reachability instance.

## Installation

CocoaPods:

```ruby
pod 'WillowTreeReachability'
```

Carthage:

```ruby
github "willowtreeapps/WillowTreeReachability" >= 2.0
```

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
reachability?.start()

reachabilitySubscription = reachability?.addSubscription(using: self)

}
```

The subscription should be held strongly by the callee to keep the subscription active.

### Stopping Reachability

In order to properly clean up when stopping the reachability notifications, the ```stop``` function should be called.
