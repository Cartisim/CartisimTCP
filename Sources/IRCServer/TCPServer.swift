//import Foundation
//import NIO
//import Dispatch
//import NIOSSL
//import AsyncHTTPClient
//import NIOExtras
//import Logging
//import NIOIRC
//
//extension SocketAddress {
//    
//    var ircOrigin : String {
//        return ""
//    }
//}
//
//
//class TCPServer {
//    
//    private var host: String?
//    private var port: Int?
//    private var origin: String?
//    public private(set) var context: ServerContext?
//    let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
//    static var httpClient: HTTPClient?
//    
//    init(host: String, port: Int, origin: String) {
//        self.host = host
//        self.port = port
//        self.origin = origin
//        TCPServer.httpClient = HTTPClient(eventLoopGroupProvider: .shared(group))
//    }
//    
//    
//    /* if we need to test if everything is flushing we can user these handlers
//     NIOExtras.DebugInboundEventsHandler(logger: { event, context in print("\(context.channel): \(context.name): \(event)"); fflush(stdout) }),
//     NIOExtras.DebugOutboundEventsHandler(logger: { event, context in print("\(context.channel): \(context.name): \(event)"); fflush(stdout) }),
//     */
//    
//    private var serverBootstrap: ServerBootstrap {
//        
//        let address : SocketAddress
//        var origin = ""
//        let logger = Logger(label: "com.cartisim.io")
//        if let host = self.host, let port = self.port {
//            
//            address = try! SocketAddress.makeAddressResolvingHost(host, port: port)
//            
//            origin = {
//                let s = self.origin ?? address.ircOrigin
//                if !s.isEmpty { return s }
//                if let s = self.host { return s }
//                return "no-origin" // TBD
//            }()
//        }
//        
//        #if DEBUG || LOCAL
//        return ServerBootstrap(group: group)
//            
//            .childChannelInitializer { channel in
////                channel.pipeline.addHandlers([
////                    BackPressureHandler()
////                ])
////                .flatMap {
//                    channel.pipeline.addHandlers([
////                        ByteToMessageHandler(LineBasedFrameDecoder()),
////                        SessionHandler<EncryptedObject>(serverContext: ServerContext(origin: origin)),
//                        BackPressureHandler(),
//                        IRCChannelHandler(),
//                        SessionHandler(logger: logger, serverContext: ServerContext(origin: "localhost", logger: logger)),
////                        MessageToByteHandler(JSONMessageEncoder<EncryptedObject>())
//                    ])
//                }
////            }
//            .childChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
//        #else
//        let basePath = FileManager().currentDirectoryPath
//        let certPath = basePath + "/fullchain.pem"
//        let keyPath = basePath + "/privkey.pem"
//        
//        let certs = try! NIOSSLCertificate.fromPEMFile(certPath)
//            .map { NIOSSLCertificateSource.certificate($0) }
//        let tls = TLSConfiguration.forServer(certificateChain: certs, privateKey: .file(keyPath))
//        let sslContext = try? NIOSSLContext(configuration: tls)
//        
//        return ServerBootstrap(group: group)
//            
//            .childChannelInitializer { channel in
//                channel.pipeline.addHandlers([
//                    NIOSSLServerHandler(context: sslContext!),
//                    BackPressureHandler()
//                ])
//                .flatMap {
//                    channel.pipeline.addHandlers([
//                        ByteToMessageHandler(LineBasedFrameDecoder()),
//                        SessionHandler<EncryptedObject>(serverContext: ServerContext(origin: origin)),
//                        MessageToByteHandler(JSONMessageEncoder<EncryptedObject>())
//                    ])
//                }
//            }
//            .childChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
//        #endif
//    }
//    
//    func shutdown() {
//        do {
//            try group.syncShutdownGracefully()
//        } catch let error {
//            print("Could not gracefully shutdown, Forcing the exit (\(error)")
//            exit(0)
//        }
//        print("closed server")
//    }
//    
//    
//    func run() throws {
//        guard let host = host else {
//            throw TCPError.invalidHost
//        }
//        guard let port = port else {
//            throw TCPError.invalidPort
//        }
//        // First argument is the program path
//        let arguments = CommandLine.arguments
//        let arg1 = arguments.dropFirst().first
//        let arg2 = arguments.dropFirst(2).first
//        
//        
//        enum BindTo {
//            case ip(host: String, port: Int)
//            case unixDomainSocket(path: String)
//        }
//        
//        let bindTarget: BindTo
//        switch (arg1, arg1.flatMap(Int.init), arg2.flatMap(Int.init)) {
//        case (.some(let h), _ , .some(let p)):
//            /* we got two arguments, let's interpret that as host and port */
//            bindTarget = .ip(host: h, port: p)
//            
//        case (let portString?, .none, _):
//            // Couldn't parse as number, expecting unix domain socket path.
//            bindTarget = .unixDomainSocket(path: portString)
//            
//        case (_, let p?, _):
//            // Only one argument --> port.
//            bindTarget = .ip(host: host, port: p)
//            
//        default:
//            bindTarget = .ip(host: host, port: port)
//        }
//        let channel = try { () -> Channel in
//            switch bindTarget {
//            case .ip(let host, let port):
//                return try serverBootstrap.bind(host: host, port: port).wait()
//            case .unixDomainSocket(let path):
//                return try serverBootstrap.bind(unixDomainSocketPath: path).wait()
//            }
//        }()
//        print("CHANNEL", channel)
//        guard let localAddress = channel.localAddress else {
//            fatalError("Address was unable to bind. Please check that the socket was not closed or that the address family was understood.")
//        }
//        print("Server started and listening on \(localAddress)")
//        //  This will never unblock as we don't close the ServerChannel.
//        try channel.closeFuture.wait()
//    }
//}