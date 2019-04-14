//
//  WebSocketCoordinator.swift
//  WebSocketCoordinator
//
//  Created by Gabriel Vincent on 13/04/19.
//  Copyright © 2019 Gabriel Vincent. All rights reserved.
//

import Foundation
import SwiftWebSocket

public typealias WebSocketPayload = [AnyHashable:Any]

public class WebSocketCoordinator:NSObject {
    
    static let manager = WebSocketCoordinator()
    
    fileprivate struct Subscription {
        
        var identifier:String
        var executionBlock:((WebSocketPayload) -> Void)
    }
    
    private var subscriptions:[Subscription] = []
    
    private override init() {
        
        super.init()
    }
    
    // MARK: - Implementation
    
    // MARK: Public
    
    func connect(ToURL url:String) {
        
        let webSocket = WebSocket(url)
        webSocket.delegate = self
        webSocket.open()
    }
    
    public func on(message identifier:String, overrideExisting:Bool = false, completion:@escaping ((WebSocketPayload) -> Void)) {
        
        let subscription = Subscription(identifier: identifier, executionBlock: completion)
        
        guard !overrideExisting else {
            
            subscriptions.update(subscription)
            return
        }
        
        subscriptions.append(subscription)
    }
    
    // MARK: Private
    
    private func log(_ string:String) {
        
        print("[WebSocketCoordinator]: \(string)")
    }
}

extension WebSocketCoordinator:WebSocketDelegate {
    
    public func webSocketOpen() {
        
        log("Did open web socket")
    }
    
    public func webSocketClose(_ code: Int, reason: String, wasClean: Bool) {
        
    }
    
    public func webSocketError(_ error: NSError) {
        
    }
    
    public func webSocketMessageData(_ data: Data) {
        
        guard
            let jsonObject = data.toJSONObject(),
            let identifier = jsonObject["indentifier"] as? String,
            let payload = jsonObject["payload"] as? WebSocketPayload
        else { return }
        
        log("Did receive message with payload: \(payload)")
        
        subscriptions.with(identifier).foreach({ (subscription) in
            
            subscription.executionBlock(payload)
            
        }, else: {
            
            self.log("'\(identifier)' is not subscribed")
        })
    }
    
    public func webSocketMessageText(_ text: String) {
        
    }
}

private extension Array where Element == WebSocketCoordinator.Subscription {
    
    func foreach(_ execute:((WebSocketCoordinator.Subscription) -> Void), else elseBlock:(() -> Void)) {
        
        var executedBlock = false
        
        for subscription in self {
            
            execute(subscription)
            executedBlock = true
        }
        
        if !executedBlock {
            
            elseBlock()
        }
    }
    
    func with(_ identifier:String) -> [WebSocketCoordinator.Subscription] {
        
        return filter({ (subscription) -> Bool in
            
            return subscription.identifier == identifier
        })
    }
    
    func contains(element:WebSocketCoordinator.Subscription) -> Bool {
        
        return contains(where: { (subscription) -> Bool in
            
            element.identifier == subscription.identifier
        })
    }
    
    mutating func update(_ subscription:WebSocketCoordinator.Subscription) {
        
        for (i, _) in self.enumerated() {
            if subscription.identifier == subscription.identifier {
                
                self[i].executionBlock = subscription.executionBlock
                return
            }
        }
    }
}

private extension Data {
    
    func toJSONObject() -> [AnyHashable:Any]? {
        
        do {
            
            return try JSONSerialization.jsonObject(with: self, options: .allowFragments) as? [AnyHashable:Any]
        }
        catch {
            
            return nil
        }
    }
}
