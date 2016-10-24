//
//  ViewController.swift
//  Reachability
//
//  Created by Erik LaManna on 8/28/15.
//  Copyright © 2015 WillowTree, Inc. All rights reserved.
//

import UIKit

class ViewController: UIViewController, NetworkStatusSubscriber {
   
    @IBOutlet weak var connectionStatusLight: UIView!
    @IBOutlet weak var connectionStatusFlagLabel: UILabel!
    
    var reachability: Monitor?
    var reachabilitySubscription: NetworkStatusSubscription?
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    deinit {
        reachability?.stop()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    
        connectionStatusLight.layer.borderWidth = 1.0 / UIScreen.main.scale
        connectionStatusLight.layer.cornerRadius = 10.0
        connectionStatusLight.layer.borderColor = UIColor.black.cgColor
        connectionStatusLight.backgroundColor = UIColor.white
        
        reachability = Monitor(withURL: NSURL(string: "http://www.willowtreeapps.com")!)
        
        // Use the following for generic internet reachability
        // self.reachability = Reachability()
        
        _ = reachability?.start()
        
        
        reachabilitySubscription = reachability?.addSubscription(using: self)

        if let reachability = reachability {
            self.networkStatusChanged(status: reachability.status)
        }
        
    }
    
    func networkStatusChanged(status: ReachabilityStatus) {
        DispatchQueue.main.async { [weak self] in
            switch status {
            case .notReachable:
                    self?.connectionStatusLight.backgroundColor = UIColor.red
            case .viaWifi, .viaCellular:
                self?.connectionStatusLight.backgroundColor = UIColor.green
            default:
                self?.connectionStatusLight.backgroundColor = UIColor.white
            }
            self?.connectionStatusFlagLabel.text = status.description
        }
    }
}

