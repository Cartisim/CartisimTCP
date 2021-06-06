import NIO
import Foundation

extension SessionHandler {
    
    
    
    public func dispatchMessage(sender: MessageSender, recipients: [ MessageRecipient ], message: String) throws {
        
        
        let sender = userID?.stringValue
        
        recipients.forEach { recipient in
            print(recipient)
            switch recipient {
            
            case .channel:
                <#code#>
            case .dm:
                <#code#>
            case .all:
                <#code#>
            }
        }
        
        
        
        
        
    }
    
    
    
    
    
    
    
    
    
    
    
    
    
    
}
public func doMessage(sender: IRCUserID?,
                      recipients: [ IRCMessageRecipient ], message: String)
              throws
{
  let sender = userID?.stringValue // Note: we do ignore the sender!

  for target in recipients {
    switch target {
      case .everything:
        sendReply(.errorNoSuchNick, "*", "No such nick/channel")

      case .nickname(let nick):
        guard let targetSession = server.getSession(of: nick) else {
          sendReply(.errorNoSuchNick, nick.stringValue,
                    "No such nick/channel '\(nick.stringValue)'")
          continue
        }

        let message = IRCMessage(origin: sender,
                                 command: .PRIVMSG([ target ], message))
        targetSession.sendMessage(message)

      case .channel(let channelName):
        // TODO: complicated: exclude self?! No => OID
        guard let targetSessions = server.getSessions(in: channelName) else {
          sendReply(.errorNoSuchChannel, channelName.stringValue,
                    "No such channel '\(channelName.stringValue)'")
          continue
        }

        let message = IRCMessage(origin: sender,
                                 command: .PRIVMSG([ target ], message))
        for session in targetSessions {
          guard session !== self else { continue }
          session.sendMessage(message)
        }
    }
  }
}
