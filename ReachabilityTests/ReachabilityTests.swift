//
//  ReachabilityTests.swift
//  ReachabilityTests
//
//  Created by Erik LaManna on 8/28/15.
//  Copyright © 2015 WillowTree, Inc. All rights reserved.
//

import XCTest
import SystemConfiguration
@testable import Reachability

class TestNetworkSubscriber: NetworkStatusSubscriber {
    
    var status: ReachabilityStatus = .unknown
    
    func networkStatusChanged(status: ReachabilityStatus) {
        self.status = status
    }
}
class ReachabilityTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testSubscriptionLifecycle() {
        if let monitor = Monitor() {
            _ = monitor.start()
            let subscriber = TestNetworkSubscriber()
            var subscription: NetworkStatusSubscription? = monitor.addSubscription(using: subscriber)

            let scNetworkCallback = Monitor.systemReachabilityCallback()
            scNetworkCallback(monitor.reachabilityReference, SCNetworkReachabilityFlags.reachable, monitor.unsafeSelfPointer)
            
            XCTAssert(monitor.subscriptions.count == 1, "Subscription count is not 1")
            if subscription != nil { 
                subscription = nil
            }
            
            XCTAssert(monitor.subscriptions.count == 0, "Subscription count is not 0")
        }
    }
    
}
