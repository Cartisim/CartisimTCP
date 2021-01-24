import Foundation

enum TCPError: Error {
    case invalidHost
    case invalidPort
}

enum TCPErrors: Error {
    case sslContextError(String)
}
