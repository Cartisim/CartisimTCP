import Foundation

struct ChatroomRequest: Codable {
    var avatar: String?
    var contactID: String
    var name: String
    var message: String
    var token: String
    var sessionID: String
    var chatSessionID: String
    
    init(avatar: String, contactID: String, name: String, message: String, token: String, sessionID: String, chatSessionID: String) {
        self.avatar = avatar
        self.contactID = contactID
        self.name = name
        self.message = message
        self.token = token
        self.sessionID = sessionID
        self.chatSessionID = chatSessionID
    }
}
