

fileprivate enum MessageDispatcherError: Swift.Error {
    case notImplemented(function: String)
}

public protocol MessageDispatcher {
    
    func sendMessage(_ message: Message) throws
    func dispatchMessage(sender: UserID, recipients: [MessageRecipient], message: String) throws
}

public extension MessageDispatcher {
    
 @inlinable
    func sendMessage(_ message: Message) throws {
        try sendDispatchMessage(message)
    }
    
    func sendDispatchMessage(message: message) throws {
        do {
            
        } catch {
            
        }
    }
    
}

public extension MessageDispatcher {
    
    func dispatchMessage(sender: UserID, recipients: [MessageRecipient], message: String) throws {
        throw MessageDispatcherError.notImplemented(function: #function)
    }
    
    
}
