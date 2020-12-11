import Foundation

struct MessageRequest: Codable {
    var avatar: String?
    var contactID: String
    var name: String
    var message: String
    var chatSessionID: String
    
    init(avatar: String, contactID: String, name: String, message: String, chatSessionID: String) {
        self.avatar = avatar
        self.contactID = contactID
        self.name = name
        self.message = message
        self.chatSessionID = chatSessionID
        
    }
}
