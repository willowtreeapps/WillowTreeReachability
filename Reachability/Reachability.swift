//
//  Reachability.swift
//
//  Copyright © 2015 WillowTree, Inc.
//
import Foundation
import SystemConfiguration

protocol ReachabilityProtocol
{
    var isReachable: Bool { get }
}

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

public class Reachability: ReachabilityProtocol {
    
    public var reachabilityStatus: ReachabilityStatus = .Unknown
    
    public var isReachable: Bool {
        get {
            return self.reachabilityStatus == .ViaWifi ||
                   self.reachabilityStatus == .ViaCellular
        }
    }
    
    typealias ReachabilityCallback = (status: ReachabilityStatus) -> Void
    
    private var reachabilityCallbacks = [String: ReachabilityCallback]()
    private var unsafeSelfPointer: UnsafeMutablePointer<Void>?
    
    private let callbackQueue = dispatch_queue_create("com.willowtreeapps.Reachability", DISPATCH_QUEUE_SERIAL)
    
    var reachabilityReference: SCNetworkReachabilityRef!
    var reachabilityFlags: SCNetworkReachabilityFlags?
    
    /**
        Initialize reachability for general internet connection
    */
    public init?()
    {
        var zeroAddress = sockaddr_in()
        bzero(&zeroAddress, sizeofValue(zeroAddress))
        zeroAddress.sin_len = UInt8(sizeofValue(zeroAddress))
        zeroAddress.sin_family = UInt8(AF_INET)
        
        let address_in = UnsafeMutablePointer<sockaddr_in>.alloc(1)
        address_in.initialize(zeroAddress)
        let address = UnsafeMutablePointer<sockaddr>(address_in)
        
        guard let reachabilityReference = SCNetworkReachabilityCreateWithAddress(nil, address) else {
            return nil;
        }
        
        self.reachabilityReference = reachabilityReference
        self.updateCurrentReachabilityStatus()
    }
    
    public init?(withAddress address: UnsafeMutablePointer<sockaddr_in>) {

        let sockaddrAddress = UnsafeMutablePointer<sockaddr>(address)

        guard let reachabilityReference = SCNetworkReachabilityCreateWithAddress(nil, sockaddrAddress) else {
            return nil;
        }
        
        self.reachabilityReference = reachabilityReference
        self.updateCurrentReachabilityStatus()
    }

    /**
    Initialize reachability checking for connection to the specified host name with URL
        
    @parameter withURL the URL of the server to connect to
    */
    public init?(withURL URL: NSURL)
    {
        guard let host = URL.host,
              let reachabilityReference = SCNetworkReachabilityCreateWithName(nil, host) else {
            return nil;
        }
        
        self.reachabilityReference = reachabilityReference
        self.updateCurrentReachabilityStatus()
    }

    
    
    deinit {
        self.stopNotifier()
        self.reachabilityReference = nil;
    }
    
    public func updateCurrentReachabilityStatus() -> ReachabilityStatus {
    
        var flags = SCNetworkReachabilityFlags()
        
        if SCNetworkReachabilityGetFlags(self.reachabilityReference, &flags) {
            self.reachabilityStatus = ReachabilityStatus.statusForReachabilityFlags(flags)
        }
        
        return self.reachabilityStatus
    }
    
    public func startNotifier() -> Bool {
        var networkReachabilityContext = SCNetworkReachabilityContext()
        let ptr = UnsafeMutablePointer<Reachability>.alloc(1)
        ptr.initialize(self)
        self.unsafeSelfPointer = UnsafeMutablePointer<Void>(ptr)
        networkReachabilityContext.info = self.unsafeSelfPointer!
        
        let unsafeContextPointer = UnsafeMutablePointer<SCNetworkReachabilityContext>.alloc(1)
        unsafeContextPointer.initialize(networkReachabilityContext)
        
        
        if SCNetworkReachabilitySetCallback(self.reachabilityReference, self.internalReachabilityCallback(), unsafeContextPointer) {
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
    
    public func addReachabilityCallback(withIdentifier identifier: String, _ completion: ((status: ReachabilityStatus) -> Void)) {
        self.reachabilityCallbacks[identifier] = completion;
    }
    
    public func removeReachabilityCallback(withIdentifier identifier: String) {
        self.reachabilityCallbacks.removeValueForKey(identifier)
    }
    
    private func internalReachabilityCallback() -> SCNetworkReachabilityCallBack {
        
        let callback: SCNetworkReachabilityCallBack = {(target: SCNetworkReachability, flags: SCNetworkReachabilityFlags, info: UnsafeMutablePointer<Void>) in
            
            let reachabiltyReference = UnsafeMutablePointer<Reachability>(info)
            let reachability = reachabiltyReference.memory

            let reachabilityStatus = ReachabilityStatus.statusForReachabilityFlags(flags)
            reachability.reachabilityStatus = reachabilityStatus
            
            for callback in reachability.reachabilityCallbacks.values {
                dispatch_async(reachability.callbackQueue) {
                    callback(status: reachability.reachabilityStatus)
                }
            }
        }
        
        return callback
    }
}
