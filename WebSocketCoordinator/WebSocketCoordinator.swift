//
//  WebSocketCoordinator.swift
//  WebSocketCoordinator
//
//  Created by Gabriel Vincent on 13/04/19.
//  Copyright © 2019 Gabriel Vincent. All rights reserved.
//

import Foundation
import Starscream

public typealias WebSocketPayload = [AnyHashable:Any]

public class WebSocketCoordinator:NSObject {
    
    public static let manager = WebSocketCoordinator()
    
    fileprivate struct Subscription {
        
        var identifier:String
        var executionBlock:((WebSocketPayload) -> Void)
    }
    
    private var webSocket:WebSocket!
    private var subscriptions:[Subscription] = []
    
    private override init() {
        
        super.init()
    }
    
    // MARK: - Implementation
    
    // MARK: Public
    
    public func connect(ToURL url:String) {
        
        guard let url = URL(string: url) else { return }
        
        webSocket = WebSocket(url: url)
        webSocket.delegate = self
        webSocket.connect()
    }
    
    public func on(message identifier:String, overrideExisting:Bool = false, completion:@escaping ((WebSocketPayload) -> Void)) {
        
        let subscription = Subscription(identifier: identifier, executionBlock: completion)
        
        guard !overrideExisting
            
            else {
            
            subscriptions.update(subscription)
            return
        }
        
        subscriptions.append(subscription)
        log("Subscribed to '\(identifier)'")
        
    }
    
    public func send(_ content:Any, toRoute route:String) {
        
        let jsonObject:[String:Any] = [
            "data": content,
            "route": route
        ]
        
        guard let stringifiedJSONObject = JSONSerialization.stringify(jsonObject) else { return }
        
        log("Sending message: \(stringifiedJSONObject)")
        
        webSocket.write(string: stringifiedJSONObject) {
            
            self.log("Did send message")
        }
    }
    
    // MARK: Private
    
    private func log(_ string:String) {
        
        print("[WebSocketCoordinator]: \(string)")
    }
}

extension WebSocketCoordinator:WebSocketDelegate {
    
    public func websocketDidDisconnect(socket: WebSocketClient, error: Error?) {
        
    }
    
    
    public func websocketDidConnect(socket: WebSocketClient) {
        log("WebSocket did connect")
    }
    
    public func websocketDidReceiveData(socket: WebSocketClient, data: Data) {
        log("WebSocket did receive data.")
    }
    
    public func websocketDidReceiveMessage(socket: WebSocketClient, text: String) {
        
        log("Did receive text: \(text)")
        
        guard
            let jsonObject = JSONSerialization.parse(text) as? [AnyHashable:Any],
            let payload = jsonObject["data"] as? WebSocketPayload,
            let identifier = jsonObject["identifier"] as? String
        else { return }
        
        subscriptions.with(identifier).foreach({ (subscription) in
            
            subscription.executionBlock(payload)
            
        }, else: {
            
            self.log("No subscriptions found for message with identifier '\(identifier)'")
        })
    }
}

private extension JSONSerialization {
    
    class func parse(_ text:String) -> Any? {
        
        do {
            
            guard let data = text.data(using: .utf8) else { return nil }
            
            return try jsonObject(with: data, options: .allowFragments)
        }
        catch {
            
            return nil
        }
    }
    
    class func stringify(_ jsonObject:Any) -> String? {
        
        do {
            
            let _data = try data(withJSONObject: jsonObject, options: .sortedKeys)
            
            return String(data: _data, encoding: .utf8)
        }
        catch { return nil }
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
