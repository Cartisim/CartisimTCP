import Foundation



struct MessageSender: Codable {
    var userID: String?
    
    init(userID: String?) {
        self.userID = userID
    }
}
