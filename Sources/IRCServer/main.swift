//#if os(Linux)
//srand(UInt32(time(nil)))
//#endif


//private let server = TCPServer(host: "localhost", port: 8081, origin: "localhost")
////let server = TCPServer(host: "127.0.0.1", port: 8081)
//do {
//    print("Server is running")
//    try server.run()
//} catch let error {
//    print("Error: \(error)")
//    server.shutdown()
//}
//
//

//===----------------------------------------------------------------------===//
//
// This source file is part of the swift-nio-irc open source project
//
// Copyright (c) 2018 ZeeZide GmbH. and the swift-nio-irc project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIOIRC project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

#if os(Linux)
  import Glibc
#endif
import func Dispatch.dispatchMain
import NIO
import NIOIRC
import IRCWebClient
import IRCElizaBot


let config = Config()

// setup a shared thread pool, for all services we run

let loopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)


// MARK: - Setup IRC Server

let ircConfig = IRCServer.Configuration(eventLoopGroup: loopGroup)
ircConfig.origin = config.origin ?? "localhost"
ircConfig.host   = config.ircURL?.host
ircConfig.port   = config.ircURL?.port ?? DefaultIRCPort

let ircServer = IRCServer(configuration: ircConfig)


// MARK: - Setup Web Client Server

let webConfig = IRCWebClientServer.Configuration(eventLoopGroup: loopGroup)
webConfig.host             = config.webURL?.host ?? ircConfig.host
webConfig.port             = config.webURL?.port ?? 1337
webConfig.ircHost          = ircConfig.host
webConfig.ircPort          = ircConfig.port
webConfig.externalHost     = config.extWebURL?.host ?? webConfig.host
webConfig.externalPort     = config.extWebURL?.port ?? webConfig.port
webConfig.autoJoinChannels = [ "#NIO", "#SwiftObjects", "#SwiftDE",
                               "#LinkerKit" ]
webConfig.autoSendMessages = [
  ( "Eliza", "Moin" )
]

let webServer = IRCWebClientServer(configuration: webConfig)


// MARK: - Run Servers

signal(SIGINT) { // Safe? Unsafe. No idea :-)
  s in ircServer.stopOnSignal(s)
}

ircServer.listen()
webServer.listen()


// MARK: - Run Bots

let elizaConfig = IRCElizaBot.Options(eventLoopGroup: loopGroup)
elizaConfig.hostname = ircConfig.host ?? "localhost"
elizaConfig.port     = ircConfig.port

let eliza = IRCElizaBot(options: elizaConfig)
eliza.connect()


// MARK: - Wait on runloop

#if false // produces Zombies in Xcode
  dispatchMain()
#else
  try? ircServer.serverChannel?.closeFuture.wait()
#endif
