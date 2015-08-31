//
//  Reachability.swift
//
//  Copyright © 2015 WillowTree, Inc.
//
import Foundation
import SystemConfiguration

public enum ReachabilityStatus: Int, CustomStringConvertible {
    /// Unknown network state
    case Unknown
    
    /// Network is not reachable
    case NotReachable
    
    /// Network is reachable via Wifi
    case ViaWifi
    
    /// Network is reachable via cellular connection
    case ViaCellular
    
    /**
        Returns the ReachabilityStatus based on the passed in reachability flags.
        
        @param flags the SCNetworkReachablityFlags to check for connectivity
    
        @return the reachability status
    */
    static func statusForReachabilityFlags(flags: SCNetworkReachabilityFlags) -> ReachabilityStatus {
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
    
    public var description: String {
        get {
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
}

public class Reachability {
    
    /// THe current reachability status
    public var reachabilityStatus: ReachabilityStatus = .Unknown
    
    /// Returns true if the network is reachable in either wifi or cellular
    public var isReachable: Bool {
        get {
            return self.reachabilityStatus == .ViaWifi ||
                   self.reachabilityStatus == .ViaCellular
        }
    }
    
    typealias ReachabilityCallback = (status: ReachabilityStatus) -> Void
    
    private var reachabilityCallbacks = [String: ReachabilityCallback]()
    private var unsafeSelfPointer = UnsafeMutablePointer<Reachability>.alloc(1)
    
    private let callbackQueue = dispatch_queue_create("com.willowtreeapps.Reachability", DISPATCH_QUEUE_CONCURRENT)
    private var monitoringStarted = false;
    
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
    
    /**
        Initialize reachability for the specified socket address.
    */
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
        self.reachabilityReference = nil;
        self.unsafeSelfPointer.dealloc(1)
    }
    
    /**
        Starts the asynchronous monitoring of network reachability.
        
        @return true if the notifications started successfully
    */
    public func startNotifier() -> Bool {
        guard !self.monitoringStarted else {
            return true
        }
        
        self.monitoringStarted = true
        
        var networkReachabilityContext = SCNetworkReachabilityContext()
        self.unsafeSelfPointer.initialize(self)
        networkReachabilityContext.info = UnsafeMutablePointer<Void>(self.unsafeSelfPointer)
        
        if SCNetworkReachabilitySetCallback(self.reachabilityReference, self.internalReachabilityCallback(), &networkReachabilityContext) {
            if SCNetworkReachabilityScheduleWithRunLoop(self.reachabilityReference, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode) {
                return true
            }
        }
        
        return false
    }
    
    /**
        Stops the current monitoring of network status.
    */
    public func stopNotifier() {
        
        guard monitoringStarted else {
            return;
        }
        
        if self.reachabilityReference != nil {
            SCNetworkReachabilityUnscheduleFromRunLoop(self.reachabilityReference, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode)
        }
        
        self.unsafeSelfPointer.destroy(1)
        monitoringStarted = false
    }
    
    /**
        Add a callback listener with the specified identifier that gets called any time the network
        status changes.

        @param withIdentifier the identifier to use with this callback
        @param callback the callback to call when the network status changes
    */
    public func addReachabilityCallback(withIdentifier identifier: String, _ callback: ((status: ReachabilityStatus) -> Void)) {
        self.reachabilityCallbacks[identifier] = callback;
    }
    
    /**
        Removes a specified callback listener.
    
        @param withIdentifier the identifier to use with this callback
    */

    public func removeReachabilityCallback(withIdentifier identifier: String) {
        self.reachabilityCallbacks.removeValueForKey(identifier)
    }
    
    /**
        Updates the current reachability status for the current instance using the reachability 
        reference.
    
        @return the reachability status retrieved from system configuration
    */
    private func updateCurrentReachabilityStatus() -> Void {
        
        var flags = SCNetworkReachabilityFlags()
        
        if SCNetworkReachabilityGetFlags(self.reachabilityReference, &flags) {
            self.reachabilityStatus = ReachabilityStatus.statusForReachabilityFlags(flags)
        }
    }

    /// Internal callback called by the system configuration framework
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
