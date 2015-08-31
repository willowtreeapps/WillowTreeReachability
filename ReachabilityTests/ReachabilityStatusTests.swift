//
//  ReachabilityStatusTests.swift
//  Reachability
//
//  Created by Erik LaManna on 8/31/15.
//  Copyright © 2015 WillowTree, Inc. All rights reserved.
//

import XCTest
import SystemConfiguration
@testable import Reachability

class ReachabilityStatusTests: XCTestCase {
    
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
        XCTAssert(status == ReachabilityStatus.NotReachable, "Status for no set flags must be not reachable")
        
    }
    /**
    Test the standard wifi connection case
    */
    func testReachabilityStatusConnectedWifi() {
        let flags = SCNetworkReachabilityFlags.Reachable
        let status = ReachabilityStatus.statusForReachabilityFlags(flags)
        XCTAssert(status == ReachabilityStatus.ViaWifi, "Status for reachable network flag must be via wifi")
    }
    
    /**
    Tests the standard cellular connection case.
    */
    func testReachabilityStatusConnectedCellular() {
        let rawFlags = SCNetworkReachabilityFlags.Reachable.rawValue | SCNetworkReachabilityFlags.IsWWAN.rawValue
        let flags = SCNetworkReachabilityFlags.init(rawValue: rawFlags)
        let status = ReachabilityStatus.statusForReachabilityFlags(flags)
        XCTAssert(status == ReachabilityStatus.ViaCellular, "Status for reachable network flag must be via cellular")
    }
    
    /**
    Tests all the various combinations of connections on traffic/demand.
    */
    func testReachabilityStatusConnectionNeeded() {
        var rawFlags = SCNetworkReachabilityFlags.ConnectionRequired.rawValue |
            SCNetworkReachabilityFlags.ConnectionOnTraffic.rawValue |
            SCNetworkReachabilityFlags.InterventionRequired.rawValue
        var flags = SCNetworkReachabilityFlags.init(rawValue: rawFlags)
        var status = ReachabilityStatus.statusForReachabilityFlags(flags)
        XCTAssert(status == ReachabilityStatus.NotReachable, "Connection on traffic reachable with intervention required set")
        
        rawFlags = SCNetworkReachabilityFlags.ConnectionRequired.rawValue |
            SCNetworkReachabilityFlags.ConnectionOnDemand.rawValue |
            SCNetworkReachabilityFlags.InterventionRequired.rawValue
        flags = SCNetworkReachabilityFlags.init(rawValue: rawFlags)
        status = ReachabilityStatus.statusForReachabilityFlags(flags)
        XCTAssert(status == ReachabilityStatus.NotReachable, "Connection on demand reachable with intervention required set")
        
        rawFlags = SCNetworkReachabilityFlags.ConnectionRequired.rawValue |
            SCNetworkReachabilityFlags.ConnectionOnDemand.rawValue
        flags = SCNetworkReachabilityFlags.init(rawValue: rawFlags)
        status = ReachabilityStatus.statusForReachabilityFlags(flags)
        XCTAssert(status == ReachabilityStatus.NotReachable, "Connection on demand reachable without reachable flag set")
        
        rawFlags = SCNetworkReachabilityFlags.ConnectionRequired.rawValue |
            SCNetworkReachabilityFlags.ConnectionOnDemand.rawValue
        flags = SCNetworkReachabilityFlags.init(rawValue: rawFlags)
        status = ReachabilityStatus.statusForReachabilityFlags(flags)
        XCTAssert(status == ReachabilityStatus.NotReachable, "Connection on traffic reachable without reachable flag set")
        
        rawFlags = SCNetworkReachabilityFlags.ConnectionRequired.rawValue |
            SCNetworkReachabilityFlags.ConnectionOnDemand.rawValue |
            SCNetworkReachabilityFlags.Reachable.rawValue
        flags = SCNetworkReachabilityFlags.init(rawValue: rawFlags)
        status = ReachabilityStatus.statusForReachabilityFlags(flags)
        XCTAssert(status == ReachabilityStatus.ViaWifi, "Connection on demand not reachable without intervention required set")
        
        rawFlags = SCNetworkReachabilityFlags.ConnectionRequired.rawValue |
            SCNetworkReachabilityFlags.ConnectionOnDemand.rawValue |
            SCNetworkReachabilityFlags.Reachable.rawValue
        flags = SCNetworkReachabilityFlags.init(rawValue: rawFlags)
        status = ReachabilityStatus.statusForReachabilityFlags(flags)
        XCTAssert(status == ReachabilityStatus.ViaWifi, "Connection on traffic not reachable without intervention required set")
    }
}
