import Foundation

struct ChatroomRequest: Codable {
    var avatar: String?
    var userID: String
    var name: String
    var message: String
    var accessToken: String
    var refreshToken: String
    var sessionID: String
    var chatSessionID: String
    
    init(avatar: String, userID: String, name: String, message: String, accessToken: String, refreshToken: String, sessionID: String, chatSessionID: String) {
        self.avatar = avatar
        self.userID = userID
        self.name = name
        self.message = message
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.sessionID = sessionID
        self.chatSessionID = chatSessionID
    }
}
