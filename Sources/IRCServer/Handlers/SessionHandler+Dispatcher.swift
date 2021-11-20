//import NIO
//import Foundation
//import NIOIRC
//
//extension SessionHandler: IRCDispatcher {
//    
//
//    
//    func doMessage(sender: IRCUserID?, recipients: [ IRCMessageRecipient ], message: String) throws {
//        let sender = userID?.stringValue
//        
//        for recipient in recipients {
//            print(recipient)
//            switch recipient {
//            
//            case .channel(let channelName):
//                guard let targetSessions = serverContext.getSessions(in: channelName) else {
//                    sendReply(.errorNoSuchChannel, channelName.stringValue,
//                              "No such channel '\(channelName.stringValue)'")
//                    continue
//                }
//                let message = IRCMessage(origin: sender, command: .PRIVMSG([ recipient ], message))
//                
//                for session in targetSessions {
//                    guard session !== self else { continue }
//                    session.sendMessage(message)
//                }
//            break
//            case .nickname(let nick):
//            guard let targetSession = serverContext.getSession(of: nick) else {
//                sendReply(.errorNoSuchNick, nick.stringValue,
//                          "No such id for this channel '\(nick.stringValue)'")
//                continue
//            }
//            
//            let message = IRCMessage(origin: sender, command: .PRIVMSG([ recipient ], message))
//            targetSession.sendMessage(message)
//            case .everything:
//            sendReply(.errorNoSuchNick, "*", "No Such id or channel")
//            }
//        }
//    }
//}
//
//
//internal protocol ServerMessageTarget: IRCMessageTarget {
//    var target: String { get }
//}
//internal extension ServerMessageTarget {
//    
//    func sendError(_ code: IRCCommandCode, message: String? = nil, _ args: String...) {
//        let enrichedArgs = args + [ message ?? code.errorMessage ]
//        let message = IRCMessage(origin: origin, target: target, command: .numeric(code, enrichedArgs))
//        sendMessage(message)
//    }
//    
//    func sendReply(_ code: IRCCommandCode, _ args: String...) {
//        let message = IRCMessage(origin: origin, target: target, command: .numeric(code, args))
//        sendMessage(message)
//    }
//    
//    func sendMotD(_ message: String) {
//      guard !message.isEmpty else { return }
//      let origin = self.origin ?? "??"
//      sendReply(.replyMotDStart, "- \(origin) Message of the Day -")
//      
//      let lines = message.components(separatedBy: "\n")
//                         .map { $0.replacingOccurrences(of: "\r", with: "") }
//                         .map { "- " + $0 }
//      
//      let messages = lines.map {
//        IRCMessage(origin: origin, command: .numeric(.replyMotD, [ target, $0 ]))
//      }
//      sendMessages(messages, promise: nil)
//      sendReply(.replyEndOfMotD, "End of /MOTD command.")
//    }
//
//}
