//
//  Reachability.swift
//
//  Copyright © 2015 WillowTree, Inc.
//
import Foundation
import SystemConfiguration

public let ReachabilityChangedNotification = "ReachabilityChangedNotification"

protocol ReachabilityProtocol
{
    var isReachable: Bool { get }
}

public class Reachability {

    public enum ReachabilityStatus: Int {
        case Unknown
        case NotReachable
        case ViaWifi
        case ViaCellular
        
        public static func statusForReachabilityFlags(flags: SCNetworkReachabilityFlags) -> ReachabilityStatus {
            
            print(flags)
            let reachable = flags.contains(.Reachable)
            let requiresConnection = flags.contains(.ConnectionRequired)
            let supportsAutomaticConnection = (flags.contains(.ConnectionOnDemand) || flags.contains(.ConnectionOnTraffic))
            let requiresUserInteraction = flags.contains(.InterventionRequired)
            let networkReachable = (reachable &&
                (!requiresConnection || (supportsAutomaticConnection && !requiresUserInteraction)))
            
            if !networkReachable {
                return .NotReachable
            } else if flags.contains(.IsWWAN) {
                return .ViaCellular
            } else {
                return .ViaWifi
            }
        }
        
        public func description() -> String
        {
            switch self {
            case .Unknown:
                return "Unknown"
            case .NotReachable:
                return "Not reachable"
            case .ViaCellular:
                return "Reachable via cellular"
            case .ViaWifi:
                return "Reachable via wifi"
            }
        }
    }
    
    public var reachabilityCallback: ((status: ReachabilityStatus) -> Void)?
    
    private var unsafeSelfPointer: UnsafeMutablePointer<Void>?
    
    var reachabilityReference: SCNetworkReachabilityRef!
    var reachabilityFlags: SCNetworkReachabilityFlags?
    
    public var reachabilityStatus: ReachabilityStatus = .Unknown
    
    public init?(withHostName hostName: String)
    {
        guard let reachabilityReference = SCNetworkReachabilityCreateWithName(nil, hostName) else {
            return nil;
        }

        self.reachabilityReference = reachabilityReference
    }
    
    deinit {
        self.stopNotifier()
        self.reachabilityReference = nil;
    }
    
    public func startNotifier() -> Bool {
        var networkReachabilityContext = SCNetworkReachabilityContext()
        let ptr = UnsafeMutablePointer<Reachability>.alloc(1)
        ptr.initialize(self)
        self.unsafeSelfPointer = UnsafeMutablePointer<Void>(ptr)
        networkReachabilityContext.info = self.unsafeSelfPointer!
        
        if SCNetworkReachabilitySetCallback(self.reachabilityReference, self.internalReachabilityCallback(), &networkReachabilityContext) {
            if SCNetworkReachabilityScheduleWithRunLoop(self.reachabilityReference, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode) {
                return true
            }
        }
        
        return false
    }
    
    public func stopNotifier() {
        if self.reachabilityReference != nil {
            SCNetworkReachabilityUnscheduleFromRunLoop(self.reachabilityReference, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode)
        }
        
        self.unsafeSelfPointer?.destroy(1)
        self.unsafeSelfPointer = nil
    }
    
    private func internalReachabilityCallback() -> SCNetworkReachabilityCallBack {
        
        let callback: SCNetworkReachabilityCallBack = {(target: SCNetworkReachability, flags: SCNetworkReachabilityFlags, info: UnsafeMutablePointer<Void>) in
            
            let reachabiltyReference = UnsafeMutablePointer<Reachability>(info)
            let reachability = reachabiltyReference.memory

            reachability.reachabilityStatus = ReachabilityStatus.statusForReachabilityFlags(flags)
            reachability.reachabilityCallback?(status: reachability.reachabilityStatus)
        }
        
        return callback
    }
}
