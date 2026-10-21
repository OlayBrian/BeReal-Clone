import Foundation
import ParseSwift

struct Comment: ParseObject {
    var objectId: String?
    var createdAt: Date?
    var updatedAt: Date?
    var ACL: ParseACL?
    var originalData: Data?

    var post: Post?
    var user: User?
    var username: String?
    var text: String?
}
