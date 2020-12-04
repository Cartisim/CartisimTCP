//#if os(Linux)
//srand(UInt32(time(nil)))
//#endif


let server = TCPServer(host: "tcptest.cartisim.io", port: 8081)
do {
    print("Server is running")
    try server.run()
} catch let error {
    print("Error: \(error.localizedDescription)")
    server.shutdown()
}


