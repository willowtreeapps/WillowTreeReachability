//
//  WillowTreeReachabilityStatusTests.swift
//  WillowTreeReachability
//
//  Created by Erik LaManna on 8/31/15.
//  Copyright © 2015 WillowTree, Inc. All rights reserved.
//

import XCTest
import SystemConfiguration
@testable import WillowTreeReachability

class WillowTreeReachabilityStatusTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    /**
    Test the standard not connected case
    */
    func testNotConnected() {
        let flags = SCNetworkReachabilityFlags(rawValue: 0)
        let status = ReachabilityStatus.statusForReachabilityFlags(flags)
        XCTAssert(status == ReachabilityStatus.notReachable, "Status for no set flags must be not reachable")
        
    }
    /**
    Test the standard wifi connection case
    */
    func testReachabilityStatusConnectedWifi() {
        let flags = SCNetworkReachabilityFlags.reachable
        let status = ReachabilityStatus.statusForReachabilityFlags(flags)
        XCTAssert(status == ReachabilityStatus.viaWifi, "Status for reachable network flag must be via wifi")
    }
    
    /**
    Tests the standard cellular connection case.
    */
    func testReachabilityStatusConnectedCellular() {
        let rawFlags = SCNetworkReachabilityFlags.reachable.rawValue | SCNetworkReachabilityFlags.isWWAN.rawValue
        let flags = SCNetworkReachabilityFlags.init(rawValue: rawFlags)
        let status = ReachabilityStatus.statusForReachabilityFlags(flags)
        XCTAssert(status == ReachabilityStatus.viaCellular, "Status for reachable network flag must be via cellular")
    }
    
    /**
    Tests all the various combinations of connections on traffic/demand.
    */
    func testReachabilityStatusConnectionNeeded() {
        var rawFlags = SCNetworkReachabilityFlags.connectionRequired.rawValue |
            SCNetworkReachabilityFlags.connectionOnTraffic.rawValue |
            SCNetworkReachabilityFlags.interventionRequired.rawValue
        var flags = SCNetworkReachabilityFlags.init(rawValue: rawFlags)
        var status = ReachabilityStatus.statusForReachabilityFlags(flags)
        XCTAssert(status == ReachabilityStatus.notReachable, "Connection on traffic reachable with intervention required set")
        
        rawFlags = SCNetworkReachabilityFlags.connectionRequired.rawValue |
            SCNetworkReachabilityFlags.connectionOnDemand.rawValue |
            SCNetworkReachabilityFlags.interventionRequired.rawValue
        flags = SCNetworkReachabilityFlags.init(rawValue: rawFlags)
        status = ReachabilityStatus.statusForReachabilityFlags(flags)
        XCTAssert(status == ReachabilityStatus.notReachable, "Connection on demand reachable with intervention required set")
        
        rawFlags = SCNetworkReachabilityFlags.connectionRequired.rawValue |
            SCNetworkReachabilityFlags.connectionOnDemand.rawValue
        flags = SCNetworkReachabilityFlags.init(rawValue: rawFlags)
        status = ReachabilityStatus.statusForReachabilityFlags(flags)
        XCTAssert(status == ReachabilityStatus.notReachable, "Connection on demand reachable without reachable flag set")
        
        rawFlags = SCNetworkReachabilityFlags.connectionRequired.rawValue |
            SCNetworkReachabilityFlags.connectionOnDemand.rawValue
        flags = SCNetworkReachabilityFlags.init(rawValue: rawFlags)
        status = ReachabilityStatus.statusForReachabilityFlags(flags)
        XCTAssert(status == ReachabilityStatus.notReachable, "Connection on traffic reachable without reachable flag set")
        
        rawFlags = SCNetworkReachabilityFlags.connectionRequired.rawValue |
            SCNetworkReachabilityFlags.connectionOnDemand.rawValue |
            SCNetworkReachabilityFlags.reachable.rawValue
        flags = SCNetworkReachabilityFlags.init(rawValue: rawFlags)
        status = ReachabilityStatus.statusForReachabilityFlags(flags)
        XCTAssert(status == ReachabilityStatus.viaWifi, "Connection on demand not reachable without intervention required set")
        
        rawFlags = SCNetworkReachabilityFlags.connectionRequired.rawValue |
            SCNetworkReachabilityFlags.connectionOnDemand.rawValue |
            SCNetworkReachabilityFlags.reachable.rawValue
        flags = SCNetworkReachabilityFlags.init(rawValue: rawFlags)
        status = ReachabilityStatus.statusForReachabilityFlags(flags)
        XCTAssert(status == ReachabilityStatus.viaWifi, "Connection on traffic not reachable without intervention required set")
    }
}
