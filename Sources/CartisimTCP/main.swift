//#if os(Linux)
//srand(UInt32(time(nil)))
//#endif


let server = TCPServer(host: "127.0.0.1", port: 8081)
do {
    print("Server is running")
    try server.run()
} catch let error {
    print("Error: \(error)")
    server.shutdown()
}


