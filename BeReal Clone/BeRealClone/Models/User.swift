//
//  User.swift
//  BeReal Clone
//
//  Created by Brian Ribeiro on 11/28/22.
//

import Foundation

// TODO: Pt 1 - Import Parse Swift
import ParseSwift

// TODO: Pt 1 - Create Parse User model
struct User: ParseUser {
    // These are required by `ParseObject`.
    var objectId: String?
    var createdAt: Date?
    var updatedAt: Date?
    var ACL: ParseACL?
    var originalData: Data?

    // These are required by `ParseUser`.
    var username: String?
    var email: String?
    var emailVerified: Bool?
    var password: String?
    var authData: [String: [String: String]?]?

    // Your custom properties.
    // var customKey: String?
}
