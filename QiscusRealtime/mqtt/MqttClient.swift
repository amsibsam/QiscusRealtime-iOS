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
    
    func publish(_ topic: String, message: String) {
        client.publish(topic, withString: message)
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
            // probably deliverd or read
            return QREventType.delivery
        }else {
            return QREventType.undefined
        }
    }
    
//    private func getRoomID(data: String, type: QREventType) -> String {
//        var id = ""
//        switch type {
//        case .comment:
//            id = getRoomID(fromComment: data)
//        case .delivery:
//
//        default:
//            return id
//        }
//        return id
//    }
    
    private func getRoomID(fromTopic: String) -> String {
        var id = ""
        
        return id
    }
    
    private func getRoomID(fromComment: String) -> String {
        var id = ""
        
        return id
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
                self.delegate?.updateUserTyping(roomId: id, userEmail: "")
                break
            case .online:
                break
            case .read:
                break
            case .delivery:
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
//        QRLogger.debugPrint("mqtt didPing")
    }
    
    func mqttDidReceivePong(_ mqtt: CocoaMQTT) {
//        QRLogger.debugPrint("mqtt didReceivePong")
    }
    
    func mqttDidDisconnect(_ mqtt: CocoaMQTT, withError err: Error?) {
//        QRLogger.debugPrint("\(err?.localizedDescription)")
//        self.realtimeConnect = false
//        self.stopPublishOnlineStatus()
    }
}
