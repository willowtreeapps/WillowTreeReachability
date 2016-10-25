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
    case unknown
    
    /// Network is not reachable
    case notReachable
    
    /// Network is reachable via Wifi
    case viaWifi
    
    /// Network is reachable via cellular connection
    case viaCellular
    
    /// Returns the ReachabilityStatus based on the passed in reachability flags.
    ///
    /// - parameter flags: the SCNetworkReachablityFlags to check for connectivity
    /// - returns: the reachability status
    static func statusForReachabilityFlags(_ flags: SCNetworkReachabilityFlags) -> ReachabilityStatus {
        let reachable = flags.contains(.reachable)
        let requiresConnection = flags.contains(.connectionRequired)
        let supportsAutomaticConnection = (flags.contains(.connectionOnDemand) || flags.contains(.connectionOnTraffic))
        let requiresUserInteraction = flags.contains(.interventionRequired)
        let networkReachable = (reachable &&
            (!requiresConnection || (supportsAutomaticConnection && !requiresUserInteraction)))
        
        if !networkReachable {
            return .notReachable
        } else if flags.contains(.isWWAN) {
            return .viaCellular
        } else {
            return .viaWifi
        }
    }
    
    /// Printable description of the given status
    public var description: String {
        get {
            switch self {
            case .unknown:
                return "Unknown"
            case .notReachable:
                return "Not reachable"
            case .viaCellular:
                return "Reachable via cellular"
            case .viaWifi:
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
        monitor?.removeSubscription(self)
    }
}

public class Monitor {
    
    /// Returns the current reachability status
    public var status: ReachabilityStatus {
        var flags = SCNetworkReachabilityFlags()
            
        if SCNetworkReachabilityGetFlags(self.reachabilityReference, &flags) {
            return ReachabilityStatus.statusForReachabilityFlags(flags)
        }
        
        return .unknown
    }
    
    var subscriptions = [NetworkStatusSubscriber]()
    var unsafeSelfPointer = UnsafeMutablePointer<Monitor>.allocate(capacity: 1)

    private let callbackQueue = DispatchQueue(label: "com.willowtreeapps.Reachability", attributes: .concurrent)
    private var monitoringStarted = false
    
    var reachabilityReference: SCNetworkReachability!
    var reachabilityFlags: SCNetworkReachabilityFlags?
    
    /// Initialize monitoring for general internet connection
    convenience public init?()
    {
        var zeroAddress = sockaddr_in()
        bzero(&zeroAddress, MemoryLayout.size(ofValue: zeroAddress))
        zeroAddress.sin_len = UInt8(MemoryLayout.size(ofValue: zeroAddress))
        zeroAddress.sin_family = UInt8(AF_INET)
        
        let address_in = UnsafeMutablePointer<sockaddr_in>.allocate(capacity: 1)
        address_in.initialize(to: zeroAddress)
        
        self.init(withAddress: address_in)
    }
    
    /// Initialize monitoring for the specified socket address.
    ///
    /// - parameter withAddress: the socket address to use when checking reachability
    public init?(withAddress address: UnsafeMutablePointer<sockaddr_in>) {

        guard let reachabilityReference = address.withMemoryRebound(to: sockaddr.self, capacity: 1, {
            return SCNetworkReachabilityCreateWithAddress(nil, $0)
        }) else {
            return nil
        }

        self.reachabilityReference = reachabilityReference
    }

    /// Initialize reachability checking for connection to the specified host name with URL
    /// - parameter withURL: the URL of the server to connect to
    public init?(withURL URL: NSURL) {
        guard let host = URL.host,
              let reachabilityReference = SCNetworkReachabilityCreateWithName(nil, host) else {
            return nil
        }
        
        self.reachabilityReference = reachabilityReference
    }

    deinit {
        reachabilityReference = nil
        unsafeSelfPointer.deallocate(capacity: 1)
    }
    
    /// Starts the asynchronous monitoring of network reachability.
    ///
    /// - return: true if the notifications started successfully
    public func start() -> Bool {
        guard !monitoringStarted else {
            return true
        }
        
        monitoringStarted = true
        
        var networkReachabilityContext = SCNetworkReachabilityContext()
        unsafeSelfPointer.initialize(to: self)
        networkReachabilityContext.info = UnsafeMutableRawPointer(unsafeSelfPointer)
        
        if SCNetworkReachabilitySetCallback(reachabilityReference, Monitor.systemReachabilityCallback(), &networkReachabilityContext) {
            if SCNetworkReachabilityScheduleWithRunLoop(reachabilityReference, CFRunLoopGetCurrent(), RunLoopMode.defaultRunLoopMode.rawValue as CFString) {
                return true
            }
        }
        
        return false
    }
    
    /// Stops the current monitoring of network reachability
    public func stop() {
        
        guard monitoringStarted else {
            return
        }
        
        if reachabilityReference != nil {
            SCNetworkReachabilityUnscheduleFromRunLoop(reachabilityReference, CFRunLoopGetCurrent(), RunLoopMode.defaultRunLoopMode.rawValue as CFString)
        }
        
        unsafeSelfPointer.deallocate(capacity: 1)
        monitoringStarted = false
    }
    
    /// Subscribes the specified subscriber for network changes. This function returns a subscription
    /// object that must be held strongly by the callee to keep the subscription active. Once the 
    /// returned subscription falls out of scope, the subscription is automatically removed.
    ///
    /// - parameter subscriber: the subscriber for network status notification changes
    /// - returns: a subscription token that must be retained for the subscription to remain active
    public func addSubscription(using subscriber: NetworkStatusSubscriber) -> NetworkStatusSubscription {
        
        let subscription = NetworkStatusSubscription(subscriber: subscriber, monitor: self)
        subscriptions.append(subscriber)
        return subscription
    }
    
    /// Removes a subscriptions from the current list of subscriptions.
    ///
    /// - parameter subscription: the subscription to remove from the list of subscribers
    public func removeSubscription(_ subscription: NetworkStatusSubscription) {
        subscriptions = subscriptions.filter {
            $0 !== subscription.subscriber
        }
    }
    
    /// Internal callback called by the system configuration framework
    static func systemReachabilityCallback() -> SCNetworkReachabilityCallBack {
        
        let callback: SCNetworkReachabilityCallBack = {(target: SCNetworkReachability, flags: SCNetworkReachabilityFlags, info: UnsafeMutableRawPointer?) in
            guard let info = info else {
                return
            }

            let reachabiltyReference = UnsafeMutablePointer<Monitor>(info.assumingMemoryBound(to: Monitor.self))
            let reachability = reachabiltyReference.pointee

            let reachabilityStatus = ReachabilityStatus.statusForReachabilityFlags(flags)
            
            for subscriber in reachability.subscriptions {
                reachability.callbackQueue.async {
                    subscriber.networkStatusChanged(status: reachabilityStatus)
                }
            }
        }
        
        return callback
    }
}
