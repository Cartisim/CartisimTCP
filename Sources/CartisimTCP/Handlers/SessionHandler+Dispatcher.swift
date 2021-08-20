import NIO
import Foundation

extension SessionHandler: Dispatcher {
    

    
    public func dispatchMessage(sender: UserID?, recipients: [ MessageRecipient ], message: String) throws {
        let sender = userID?.stringValue
        
        for recipient in recipients {
            print(recipient)
            switch recipient {
            
            case .channel(let channelName):
                guard let targetSessions = serverContext.getSessions(in: channelName) else {
                    sendReply(.errorNoSuchChannel, channelName.stringValue,
                              "No such channel '\(channelName.stringValue)'")
                    continue
                }
                let message = Message(origin: sender, command: .PRIVMSG([ recipient ], message))
                
                for session in targetSessions {
                    guard session !== self else { continue }
                    session.sendMessage(message)
                }
            break
            case .dm(let id):
            guard let targetSession = serverContext.getSession(of: id) else {
                sendReply(.errorNoSuchDMID, id.stringValue,
                          "No such id for this channel '\(id.stringValue)'")
                continue
            }
            
            let message = Message(origin: sender, command: .PRIVMSG([ recipient ], message))
            targetSession.sendMessage(message)
            case .all:
            sendReply(.errorNoSuchDMID, "*", "No Such id or channel")
            }
        }
    }
}


internal protocol ServerMessageTarget: MessageTarget {
    var target: String { get }
}
internal extension ServerMessageTarget {
    
    func sendError(_ code: CommandCode, message: String? = nil, _ args: String...) {
        let enrichedArgs = args + [ message ?? code.errorMessage ]
        let message = Message(origin: origin, target: target, command: .numeric(code, enrichedArgs))
        sendMessage(message)
    }
    
    func sendReply(_ code: CommandCode, _ args: String...) {
        let message = Message(origin: origin, target: target, command: .numeric(code, args))
        sendMessage(message)
    }
}


internal protocol MessageTarget {
  
  var origin : String? { get }
  
  func sendMessages<T: Collection>(_ messages: T,
                                   promise: EventLoopPromise<Void>?)
         where T.Element == Message
  
}


internal extension MessageTarget {

  @inlinable
  func sendMessage(_ message: Message,
                   promise: EventLoopPromise<Void>? = nil)
  {
    sendMessages([ message ], promise: promise)
  }
}

internal extension MessageTarget {
  
  @inlinable
  func sendMessage(_ text: String, to recipients: MessageRecipient...) {
    guard !recipients.isEmpty else { return }
    
    let lines = text.components(separatedBy: "\n")
                    .map { $0.replacingOccurrences(of: "\r", with: "") }
    
    let messages = lines.map {
      Message(origin: origin, command: .PRIVMSG(recipients, $0))
    }
    sendMessages(messages, promise: nil)
  }
  
  @inlinable
  func sendNotice(_ text: String, to recipients: MessageRecipient...) {
    guard !recipients.isEmpty else { return }
    
    let lines = text.components(separatedBy: "\n")
                    .map { $0.replacingOccurrences(of: "\r", with: "") }

    let messages = lines.map {
      Message(origin: origin, command: .NOTICE(recipients, $0))
    }
    sendMessages(messages, promise: nil)
  }
  
  @inlinable
  func sendRawReply(_ code: CommandCode, _ args: String...) {
    sendMessage(Message(origin: origin, command: .numeric(code, args)))
  }
}
