import Foundation
import NIO
import Dispatch
import NIOSSL
import AsyncHTTPClient

public class TCPServer {
    
    private var host: String?
    private var port: Int?
    
    init(host: String, port: Int) {
        self.host = host
        self.port = port
    }
    
    let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
    
    private var serverBootstrap: ServerBootstrap {
        #if DEBUG || LOCAL
        return ServerBootstrap(group: group)
            .childChannelInitializer { channel in
                channel.pipeline.addHandler(BackPressureHandler()).flatMap { v in
                    channel.pipeline.addHandler(ChatHandler())
                }
            }
            .childChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
        #else
        let basePath = FileManager().currentDirectoryPath
        let certPath = basePath + "/cert.pem"
        let keyPath = basePath + "/privkey.pem"
        print(certPath, keyPath)
        let certs = try! NIOSSLCertificate.fromPEMFile(certPath)
            .map { NIOSSLCertificateSource.certificate($0) }
        let tls = TLSConfiguration.forServer(certificateChain: certs, privateKey: .file(keyPath))
        let sslContext = try? NIOSSLContext(configuration: tls)
        
        return ServerBootstrap(group: group)
            
            .childChannelInitializer { channel in
                channel.pipeline.addHandler(NIOSSLServerHandler(context: sslContext!))
                    .flatMap { _ in
                    channel.pipeline.addHandler(BackPressureHandler())
                        .flatMap { _ in
                        channel.pipeline.addHandler(ChatHandler())
                    }
                }
            }
            .childChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
        #endif
    }
    
    
    func shutdown() {
        do {
            try group.syncShutdownGracefully()
        } catch let error {
            print("Could not gracefully shutdown, Forcing the exit (\(error.localizedDescription)")
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
        print("HOST:", host, "PORT:", port)
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
        print("BINDTARGET:", bindTarget)
        let channel = try { () -> Channel in
            switch bindTarget {
            case .ip(let host, let port):
                print("IP HOST:", host, "IP PORT:", port)
                return try serverBootstrap.bind(host: host, port: port).wait()
            case .unixDomainSocket(let path):
                print("UDS PATH:", path)
                return try serverBootstrap.bind(unixDomainSocketPath: path).wait()
            }
        }()
        print("CHANNEL", channel)
        guard let localAddress = channel.localAddress else {
            fatalError("Address was unable to bind. Please check that the socket was not closed or that the address family was understood.")
        }
        print("Server started and listening on \(localAddress)")
        
        //  This will never unblock as we don't close the ServerChannel.
        try channel.closeFuture.wait()
    }
}

fileprivate func fetchKeys() throws {
    let homePath = FileManager().currentDirectoryPath
    let certPath = homePath + "/cert.pem"
    #if DEBUG || LOCAL
    let keyPath = homePath + "/key.pem"
    #else
    let keyPath = homePath + "/privkey.pem"
    #endif
    let certs = try NIOSSLCertificate.fromPEMFile(certPath)
        .map { NIOSSLCertificateSource.certificate($0) }
    do {
        let privateKey = try NIOSSLPrivateKey(file: keyPath, format: .pem)
        let configuration = TLSConfiguration.forClient(minimumTLSVersion: .tlsv12, certificateChain: certs,
                                                       privateKey: .privateKey( privateKey))
        
        let httpClient = HTTPClient(eventLoopGroupProvider: .createNew, configuration: HTTPClient.Configuration(tlsConfiguration: configuration))
        var request = try HTTPClient.Request(url: "\(Constants.BASE_URL)fetchKeys", method: .GET)
        request.headers.add(name: "User-Agent", value: "Swift HTTPClient")
        request.headers.add(name: "Content-Type", value: "application/json")
        request.headers.add(name: "Authorization", value: "Bearer")
        request.headers.add(name: "Connection", value: "keep-alive")
        request.headers.add(name: "Content-Length", value: "")
        request.headers.add(name: "Date", value: "\(Date())")
        request.headers.add(name: "Server", value: "TCPCartisim")
        request.headers.add(name: "content-security-policy", value: "default-src 'none'")
        request.headers.add(name: "x-content-type-options", value: "nosniff")
        request.headers.add(name: "x-frame-options", value: "DENY")
        request.headers.add(name: "x-xss-protection", value: "1; mode=block")
        httpClient.execute(request: request)
            .whenComplete { result in
                switch result {
                case .failure(let error):
                    print(error, "FAILURE ERROR")
                case .success(let response):
                    if response.status == .ok {
                        do {
                            guard let responseData = response.body else {return}
                            let objects = try JSONDecoder().decode([Keys].self, from: responseData)
                            KeyData.shared.keychainEncryptionKey = objects.last?.keychainEncryptionKey ?? ""
                        } catch {
                            print(error, "ERROR")
                        }
                    } else {
                        print(response.status, "Remote Error")
                    }
                }
                do {
                    try httpClient.syncShutdown()
                } catch {
                    print(error, "Error")
                }
            }
    } catch {
        print(error)
    }
}


class Keys: Codable {
    var keychainEncryptionKey: String?
    
    init(keychainEncryptionKey: String? = "") {
        self.keychainEncryptionKey = keychainEncryptionKey
    }
}

struct KeyData {
    static var shared = KeyData()
    
    fileprivate var _keychainEncryptionKey: String = ""
    
    var keychainEncryptionKey: String {
        get {
            return _keychainEncryptionKey
        }
        set {
            _keychainEncryptionKey = newValue
        }
    }
}
enum TCPErrors: Error {
    case sslContextError(String)
}


//            .serverChannelOption(ChannelOptions.backlog, value: 256)
//            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
//            .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
//

//            .childChannelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: 1)
//            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 16)
//            .childChannelOption(ChannelOptions.recvAllocator, value: AdaptiveRecvByteBufferAllocator())
