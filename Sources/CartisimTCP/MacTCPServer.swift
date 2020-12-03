import Network

//If we ever want to run this server on a mac instead of linux we can try and user NWConnection, Other wise we need to use our NIO TCP Server
@available(OSX 10.14, *)
class MacTCPServer {
    var listener: NWListener
    var queue: DispatchQueue
    var connected: Bool = false
    
    
    init?() {
        queue = DispatchQueue(label: "TCP SERVER QUEUE")
        
        listener = try! NWListener(using: .tcp, on: 8080)
       
        listener.service = NWListener.Service(type: "_chat._tcp")
        listener.serviceRegistrationUpdateHandler = { (serviceChange) in
            switch(serviceChange) {
            case .add(let endpoint):
                switch endpoint {
                case let .service(name: name, type: _, domain: _, interface: _):
                    print("Listening as \(name)")
                default:
                    break
                }
            default:
                break
            }
        }
        listener.newConnectionHandler = { [weak self] (newConnection) in
            if let strongSelf = self {
                newConnection.start(queue: strongSelf.queue)
                strongSelf.receive(on: newConnection)
            }
        }
        
        listener.stateUpdateHandler = { [weak self] (newState) in
            switch(newState) {
            case .ready:
                print("Listentning on Port \(String(describing: self?.listener.port))")
            case .failed(let error):
                print("Listener failed with error: \(error)")
            default:
                break
            }
        }
        listener.start(queue: queue)
    }
    func receive(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 10000) { (content, context, isComplete, error) in
            if let frame = content {
                if !self.connected {
                    connection.send(content: frame, completion: .idempotent)
                    print("Echoed initial content: \(frame)")
                    self.connected = true
                } else {
                 print("Not Connected")
                }
                if error == nil {
                    self.receive(on: connection)
                }
            }
        }
    }
}




