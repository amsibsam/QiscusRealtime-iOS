//
//  MqttClient.swift
//  QiscusCore
//
//  Created by Qiscus on 09/08/18.
//

import Foundation
import CocoaMQTT

enum QREventType {
    case comment
    case typing
    case online
    case read
    case delivery
    case undefined
}

class MqttClient {
    var client              : CocoaMQTT
    var delegate            : QiscusRealtimeDelegate? = nil
    var connectionState     : QiscusRealtimeConnectionState = .disconnected
    var isConnect : Bool {
        get {
            if connectionState == .connected {
                return true
            }else {
                return false
            }
        }
    }
    
    init(clientID: String, host: String, port: UInt16) {
        client = CocoaMQTT.init(clientID: clientID, host: host, port: port)
    }
    
    func connect(username: String, password: String) -> Bool {
        client.username = username
        client.password = password
        //        client.willMessage = CocoaMQTTWill(topic: "/will", message: "dieout")
        client.keepAlive = 60
        client.delegate = self
        return client.connect()
    }
    
    func publish(_ topic: String, message: String) -> Bool {
        if self.connectionState == .connected {
            client.publish(topic, withString: message)
            return true
        }else {
            QRLogger.debugPrint("can't publish \(topic)")
            return false
        }
    }
    
    func subscribe(_ topic: String) -> Bool {
        if self.connectionState == .connected {
            client.subscribe(topic, qos: .qos0)
            return true
        }else {
            // delay subscribe
            QRLogger.debugPrint("delay subscribe \(topic)")
            return false
        }
    }
    
    func unsubscribe(_ topic: String) {
        client.unsubscribe(topic)
    }
    
    func disconnect(){
        self.client.disconnect()
    }
    
    private func getEventType(topic: String) -> QREventType {
        // MARK: TODO check other type
        let word = topic.components(separatedBy: "/")
        // follow this doc https://quip.com/JpRjA0qjmINd
        if word.count == 2 {
            // probably new comment
            if word[1] == "c" {
                return QREventType.comment
            }else {
                return QREventType.undefined
            }
        }else if word.count == 5 {
            // probably deliverd or read or typing
            if word.last == "t" {
                return QREventType.typing
            }else if word.last == "r" {
                return QREventType.read
            }else if word.last == "d" {
                return QREventType.delivery
            }else{
                return QREventType.undefined
            }
        }else {
            return QREventType.undefined
        }
    }
    
    /// Get room id from topic typing
    private func getRoomID(fromTopic topic: String) -> String {
        let r = topic.replacingOccurrences(of: "r/", with: "")
        let t = r.replacingOccurrences(of: "/t", with: "")
        let id = t.components(separatedBy: "/")
        return id.first ?? ""
    }
    /// Get email from topic typing
    private func getUser(fromTopic topic: String) -> String {
        let r = topic.replacingOccurrences(of: "r/", with: "")
        let t = r.replacingOccurrences(of: "/t", with: "")
        let email = t.components(separatedBy: "/")
        return email.last ?? ""
    }
    
    private func getUserOnline(fromTopic topic: String) -> String {
        let r = topic.replacingOccurrences(of: "u/", with: "")
        let t = r.replacingOccurrences(of: "/s", with: "")
        let email = t.components(separatedBy: "/")
        return email.first ?? ""
    }
    
    /// get comment id and unique id from event message status deliverd or read
    ///
    /// - Parameter topic: mqtt payload
    /// - Returns: comment id and unique id
    private func getCommentId(fromPayload payload: String) -> (String,String) {
        // example payload :
        // {commentId}:{commentUniqueId}
        let ids = payload.components(separatedBy: ":")
        return(ids.first ?? "", ids.last ?? "")
    }
    
    /// get user is Online and timestampt
    ///
    /// - Parameter payload: mqtt payload
    /// - Returns: isOnline and timestampt in UTC
    private func getIsOnlineAndTime(fromPayload payload: String) -> (Bool,String) {
        // example payload :
        // **{1|0}:timestamp**
        let ids = payload.components(separatedBy: ":")
        return(Bool(ids.first ?? "0") ?? false, ids.last ?? "")
    }
}

extension MqttClient: CocoaMQTTDelegate {
    // Optional ssl CocoaMQTTDelegate
    func mqtt(_ mqtt: CocoaMQTT, didReceive trust: SecTrust, completionHandler: @escaping (Bool) -> Void) {
        completionHandler(true)
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didConnectAck ack: CocoaMQTTConnAck) {
        //        let state = UIApplication.shared.applicationState
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didStateChangeTo state: CocoaMQTTConnState) {
        self.connectionState = QiscusRealtimeConnectionState(rawValue: state.description)!
        self.delegate?.connectionState(change: QiscusRealtimeConnectionState(rawValue: self.connectionState.rawValue) ?? .disconnected)
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didPublishMessage message: CocoaMQTTMessage, id: UInt16) {
        if let messageData = message.string {
            QRLogger.debugPrint("didPublishMessage \n===== topic: \(message.topic) \n===== data: \(messageData)")
        }
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didPublishAck id: UInt16) {
        
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didReceiveMessage message: CocoaMQTTMessage, id: UInt16 ) {
        if let messageData = message.string {
            QRLogger.debugPrint("didReceiveMessage \n===== topic: \(message.topic) \n===== data: \(messageData)")
            let type = getEventType(topic: message.topic)
            switch type {
            case .comment:
                //                let id = getRoomID(fromComment: messageData)
                self.delegate?.didReceiveMessage(data: messageData)
            case .typing:
                let id = getRoomID(fromTopic: message.topic)
                let user = getUser(fromTopic: message.topic)
                self.delegate?.didReceiveUser(typing: Bool(messageData) ?? false, roomId: id, userEmail: user)
                break
            case .online:
                let user = getUserOnline(fromTopic: message.topic)
                let (isOnline,time) = getIsOnlineAndTime(fromPayload: messageData)
                self.delegate?.didReceiveUser(userEmail: user, isOnline: isOnline, timestamp: time)
                break
            case .read:
                let room          = getRoomID(fromTopic: message.topic)
                let (id,uniqueID) = getCommentId(fromPayload: messageData)
                self.delegate?.didReceiveMessageStatus(roomId: room, commentId: id, commentUniqueId: uniqueID, Status: .read)
                break
            case .delivery:
                let room          = getRoomID(fromTopic: message.topic)
                let (id,uniqueID) = getCommentId(fromPayload: messageData)
                self.delegate?.didReceiveMessageStatus(roomId: room, commentId: id, commentUniqueId: uniqueID, Status: .delivered)
                break
            case .undefined:
                break
            }
        }
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didSubscribeTopic topic: String) {
        QRLogger.debugPrint("didSubscribeTopic: \(topic)")
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didUnsubscribeTopic topic: String) {
        QRLogger.debugPrint("didUnsubscribeTopic: \(topic)")
    }
    
    func mqttDidPing(_ mqtt: CocoaMQTT) {
        QRLogger.debugPrint("PING")
    }
    
    func mqttDidReceivePong(_ mqtt: CocoaMQTT) {
        QRLogger.debugPrint("PONG")
    }
    
    func mqttDidDisconnect(_ mqtt: CocoaMQTT, withError err: Error?) {
         QRLogger.debugPrint("disconnected")
    }
}
