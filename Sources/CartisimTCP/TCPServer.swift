import Foundation
import NIO
import Dispatch
import NIOSSL
import AsyncHTTPClient
import NIOExtras

public class TCPServer {
    
    private var host: String?
    private var port: Int?
    let chatHandler = ChatHandler()
    let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
    static var httpClient: HTTPClient?
    
    init(host: String, port: Int) {
        self.host = host
        self.port = port
        TCPServer.httpClient = HTTPClient(eventLoopGroupProvider: .shared(group))
    }
    
    private var serverBootstrap: ServerBootstrap {
        //        #if DEBUG || LOCAL
        //        return ServerBootstrap(group: group)
        //
        //            .childChannelInitializer { channel in
        //                channel.pipeline.addHandler(NIOExtras.DebugInboundEventsHandler()).flatMap { v in
        //                    channel.pipeline.addHandler(NIOExtras.DebugOutboundEventsHandler()).flatMap { v in
        //                        channel.pipeline.addHandler(BackPressureHandler()).flatMap { v in
        //                            //                channel.pipeline.addHandler(ByteToMessageHandler(LineDelimiterCodec())).flatMap { v in
        //                            channel.pipeline.addHandler(self.chatHandler)
        //                        }
        //                    }
        //                }
        //                //                }
        //            }
        //            .childChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
        //        #else
        let basePath = FileManager().currentDirectoryPath
        let certPath = basePath + "/fullchain.pem"
        let keyPath = basePath + "/privkey.pem"
        
        let certs = try! NIOSSLCertificate.fromPEMFile(certPath)
            .map { NIOSSLCertificateSource.certificate($0) }
        let tls = TLSConfiguration.forServer(certificateChain: certs, privateKey: .file(keyPath))
        let sslContext = try? NIOSSLContext(configuration: tls)
        
        return ServerBootstrap(group: group)
            
            
            .childChannelInitializer { channel in
                channel.pipeline.addHandler(NIOSSLServerHandler(context: sslContext!))
                    .flatMap {
                        channel.pipeline.addHandler(BackPressureHandler())
                            .flatMap {                                           channel.pipeline.addHandlers([NIOExtras.DebugInboundEventsHandler(), NIOExtras.DebugOutboundEventsHandler(), self.chatHandler, NIOExtras.DebugInboundEventsHandler(), NIOExtras.DebugOutboundEventsHandler()])
                            }
                    }
            }
            
            
            //            .childChannelInitializer { channel in
            //                channel.pipeline.addHandler(NIOExtras.DebugInboundEventsHandler())
            //                    .flatMap { v in
            //                    channel.pipeline.addHandler(NIOExtras.DebugOutboundEventsHandler())
            //                        .flatMap { v in
            //                        channel.pipeline.addHandler(NIOSSLServerHandler(context: sslContext!))
            //                            .flatMap { _ in
            //                                channel.pipeline.addHandler(BackPressureHandler())
            //                                    .flatMap { v in
            //                                        channel.pipeline.addHandler(self.chatHandler)
            //                                            .flatMap { v in
            //                                            channel.pipeline.addHandler(NIOExtras.DebugInboundEventsHandler())
            //                                                .flatMap { v in
            //                                                channel.pipeline.addHandler(NIOExtras.DebugOutboundEventsHandler())
            //                                                }
            //                                            }
            //                                    }
            //                            }
            //                    }
            //                }
            //            }
            .childChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
        //        #endif
    }
    
    
    func shutdown() {
        do {
            try group.syncShutdownGracefully()
        } catch let error {
            print("Could not gracefully shutdown, Forcing the exit (\(error)")
            exit(0)
        }
        print("closed server")
    }
    
    func run() throws {
        guard let host = host else {
            throw TCPError.invalidHost
        }
        guard let port = port else {
            throw TCPError.invalidPort
        }
        // First argument is the program path
        let arguments = CommandLine.arguments
        let arg1 = arguments.dropFirst().first
        let arg2 = arguments.dropFirst(2).first
        
        
        enum BindTo {
            case ip(host: String, port: Int)
            case unixDomainSocket(path: String)
        }
        
        let bindTarget: BindTo
        switch (arg1, arg1.flatMap(Int.init), arg2.flatMap(Int.init)) {
        case (.some(let h), _ , .some(let p)):
            /* we got two arguments, let's interpret that as host and port */
            bindTarget = .ip(host: h, port: p)
            
        case (let portString?, .none, _):
            // Couldn't parse as number, expecting unix domain socket path.
            bindTarget = .unixDomainSocket(path: portString)
            
        case (_, let p?, _):
            // Only one argument --> port.
            bindTarget = .ip(host: host, port: p)
            
        default:
            bindTarget = .ip(host: host, port: port)
        }
        let channel = try { () -> Channel in
            switch bindTarget {
            case .ip(let host, let port):
                return try serverBootstrap.bind(host: host, port: port).wait()
            case .unixDomainSocket(let path):
                return try serverBootstrap.bind(unixDomainSocketPath: path).wait()
            }
        }()
        print("CHANNEL", channel)
        guard let localAddress = channel.localAddress else {
            fatalError("Address was unable to bind. Please check that the socket was not closed or that the address family was understood.")
        }
        print("Server started and listening on \(localAddress)")
        do {
            try fetchKeys()
        } catch {
            print(error, "FetchKeys Error")
        }
        //  This will never unblock as we don't close the ServerChannel.
        try channel.closeFuture.wait()
    }
    
    fileprivate func fetchKeys() throws {
        var request = try HTTPClient.Request(url:  "\(Constants.BASE_URL)fetch-keys", method: .GET)
        request.headers.add(contentsOf: Headers.headers(token: ""))
        if let result = try? TCPServer.httpClient?.execute(request: request).wait() {
            if result.status == .ok {
                guard let responseData = result.body else {return}
                let objects = try JSONDecoder().decode([Keys].self, from: responseData)
                KeyData.shared.keychainEncryptionKey = objects.last?.keychainEncryptionKey ?? ""
            } else {
                print(result.status, "Remote Error")
            }
        }
    }
}
