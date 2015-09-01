//
//  Reachability.swift
//
//  Copyright © 2015 WillowTree, Inc.
//
import Foundation
import SystemConfiguration

public protocol NetworkStatusSubscriber: class {
    func networkStatusChanged(status: ReachabilityStatus)
}

/// Enumeration representing the current network connection status
public enum ReachabilityStatus: Int, CustomStringConvertible {
    /// Unknown network state
    case Unknown
    
    /// Network is not reachable
    case NotReachable
    
    /// Network is reachable via Wifi
    case ViaWifi
    
    /// Network is reachable via cellular connection
    case ViaCellular
    
    /// Returns the ReachabilityStatus based on the passed in reachability flags.
    ///
    /// - parameter flags: the SCNetworkReachablityFlags to check for connectivity
    /// - returns: the reachability status
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
    
    /// Printable description of the given status
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

/// Subscription token used to keep a subscription to the network montitoring alive.
public class NetworkStatusSubscription {
    
    weak var subscriber: NetworkStatusSubscriber?
    weak var monitor: Monitor?
    
    init(subscriber: NetworkStatusSubscriber?, monitor: Monitor?)
    {
        self.subscriber = subscriber
        self.monitor = monitor
    }
    
    deinit {
        self.monitor?.removeReachabilitySubscription(self)
    }
}

public class Monitor {
    
    /// Returns the current reachability status
    public var reachabilityStatus: ReachabilityStatus {
        get {
            var flags = SCNetworkReachabilityFlags()
            
            if SCNetworkReachabilityGetFlags(self.reachabilityReference, &flags) {
                return ReachabilityStatus.statusForReachabilityFlags(flags)
            }
            
            return .Unknown
        }
    }
    
    var reachabilitySubscriptions = [NetworkStatusSubscriber]()
    var unsafeSelfPointer = UnsafeMutablePointer<Monitor>.alloc(1)
    
    private let callbackQueue = dispatch_queue_create("com.willowtreeapps.Reachability", DISPATCH_QUEUE_CONCURRENT)
    private var monitoringStarted = false;
    
    var reachabilityReference: SCNetworkReachabilityRef!
    var reachabilityFlags: SCNetworkReachabilityFlags?
    
    /// Initialize monitoring for general internet connection
    convenience public init?()
    {
        var zeroAddress = sockaddr_in()
        bzero(&zeroAddress, sizeofValue(zeroAddress))
        zeroAddress.sin_len = UInt8(sizeofValue(zeroAddress))
        zeroAddress.sin_family = UInt8(AF_INET)
        
        let address_in = UnsafeMutablePointer<sockaddr_in>.alloc(1)
        address_in.initialize(zeroAddress)
        
        self.init(withAddress: address_in)
    }
    
    /// Initialize monitoring for the specified socket address.
    ///
    /// - parameter withAddress: the socket address to use when checking reachability
    public init?(withAddress address: UnsafeMutablePointer<sockaddr_in>) {

        let sockaddrAddress = UnsafeMutablePointer<sockaddr>(address)

        guard let reachabilityReference = SCNetworkReachabilityCreateWithAddress(nil, sockaddrAddress) else {
            return nil;
        }
        
        self.reachabilityReference = reachabilityReference
    }

    /// Initialize reachability checking for connection to the specified host name with URL
    /// - parameter withURL: the URL of the server to connect to
    public init?(withURL URL: NSURL) {
        guard let host = URL.host,
              let reachabilityReference = SCNetworkReachabilityCreateWithName(nil, host) else {
            return nil;
        }
        
        self.reachabilityReference = reachabilityReference
    }

    deinit {
        self.reachabilityReference = nil;
        self.unsafeSelfPointer.dealloc(1)
    }
    
    /// Starts the asynchronous monitoring of network reachability.
    ///
    /// - return: true if the notifications started successfully
    public func startMonitoring() -> Bool {
        guard !self.monitoringStarted else {
            return true
        }
        
        self.monitoringStarted = true
        
        var networkReachabilityContext = SCNetworkReachabilityContext()
        self.unsafeSelfPointer.initialize(self)
        networkReachabilityContext.info = UnsafeMutablePointer<Void>(self.unsafeSelfPointer)
        
        if SCNetworkReachabilitySetCallback(self.reachabilityReference, Monitor.systemReachabilityCallback(), &networkReachabilityContext) {
            if SCNetworkReachabilityScheduleWithRunLoop(self.reachabilityReference, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode) {
                return true
            }
        }
        
        return false
    }
    
    /// Stops the current monitoring of network reachability
    public func stopMonitoring() {
        
        guard monitoringStarted else {
            return;
        }
        
        if self.reachabilityReference != nil {
            SCNetworkReachabilityUnscheduleFromRunLoop(self.reachabilityReference, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode)
        }
        
        self.unsafeSelfPointer.destroy(1)
        monitoringStarted = false
    }
    
    /// Add a subscriber for network status notifications. This function returns a subscription 
    /// object that must be held strongly by the callee to keep the subscription active. Once the 
    /// returned subscription falls out of scope, the subscription is automatically removed.
    ///
    /// - parameter subscriber: the subscriber for network status notification changes
    /// - returns: a subscription token that must be retained for the subscription to remain active
    public func addReachabilitySubscriber(subscriber: NetworkStatusSubscriber) -> NetworkStatusSubscription {
        
        let subscription = NetworkStatusSubscription(subscriber: subscriber, monitor: self)
        self.reachabilitySubscriptions.append(subscriber)
        return subscription
    }
    
    /// Removes a subscriber from the list of subscriptions.
    ///
    /// - parameter subscription: the subscription to remove from the list of subscribers
    public func removeReachabilitySubscription(subscription: NetworkStatusSubscription) {
        self.reachabilitySubscriptions = self.reachabilitySubscriptions.filter {
            if $0 === subscription.subscriber {
                return false
            }
            
            return true
        }
    }
    
    /// Internal callback called by the system configuration framework
    static func systemReachabilityCallback() -> SCNetworkReachabilityCallBack {
        
        let callback: SCNetworkReachabilityCallBack = {(target: SCNetworkReachability, flags: SCNetworkReachabilityFlags, info: UnsafeMutablePointer<Void>) in
            
            let reachabiltyReference = UnsafeMutablePointer<Monitor>(info)
            let reachability = reachabiltyReference.memory

            let reachabilityStatus = ReachabilityStatus.statusForReachabilityFlags(flags)
            
            for subscriber in reachability.reachabilitySubscriptions {
                
                dispatch_async(reachability.callbackQueue) {
                    subscriber.networkStatusChanged(reachabilityStatus)
                }
            }
        }
        
        return callback
    }
}
