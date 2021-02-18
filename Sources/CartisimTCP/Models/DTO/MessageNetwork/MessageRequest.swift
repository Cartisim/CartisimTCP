import Foundation

struct MessageRequest: Codable {
    var avatar: String?
    var userID: String
    var name: String
    var message: String
    var chatSessionID: String
    
    init(avatar: String, userID: String, name: String, message: String, chatSessionID: String) {
        self.avatar = avatar
        self.userID = userID
        self.name = name
        self.message = message
        self.chatSessionID = chatSessionID
        
    }
}
