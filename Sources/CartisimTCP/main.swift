//#if os(Linux)
//srand(UInt32(time(nil)))
//#endif



#if DEBUG || LOCAL
let server = TCPServer(host: "127.0.0.1", port: 8081)
#else
let server = TCPServer(host: "127.0.0.1", port: 8081)
#endif
do {
    print("Server is running")
    try server.run()
} catch let error {
    print("Error: \(error)")
    server.shutdown()
}


