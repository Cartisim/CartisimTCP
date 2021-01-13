//#if os(Linux)
//srand(UInt32(time(nil)))
//#endif



#if DEBUG || LOCAL
let server = TCPServer(host: "localhost", port: 8081)
#else
let server = TCPServer(host: "159.65.103.99", port: 8081)
#endif
do {
    print("Server is running")
    try server.run()
} catch let error {
    print("Error: \(error.localizedDescription)")
    server.shutdown()
}


