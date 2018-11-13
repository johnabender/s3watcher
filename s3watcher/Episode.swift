//
//  Episode.swift
//  s3watcher
//
//  Created by John Bender on 12/10/16.
//  Copyright © 2016 Bender Systems, LLC. All rights reserved.
//

import Foundation

fileprivate let baseUrl = URL(string: "https://s3-us-west-2.amazonaws.com/bender-video/")!

class Episode : NSObject {
    private var group: String
    private(set) var publicUrl: URL

    private var ratingKey: String
    private var lastPlayedKey: String

    var rating: Int {
        didSet {
            UserDefaults.standard.set(self.rating, forKey: self.ratingKey)
        }
    }
    func loadRating() -> Int {
        return UserDefaults.standard.integer(forKey: self.ratingKey)
    }

    var lastPlayed: Date {
        didSet {
            UserDefaults.standard.set(self.lastPlayed.timeIntervalSince1970, forKey: self.lastPlayedKey)
        }
    }
    func loadLastPlayed() -> Date {
        return Date(timeIntervalSince1970: UserDefaults.standard.double(forKey: self.lastPlayedKey))
    }

    override var description: String {
        return self.publicUrl.description
    }

    init(group: String, key: String) {
        self.group = group
        self.publicUrl = URL(string: key, relativeTo: baseUrl)!

        self.ratingKey = key + "_rating"
        self.lastPlayedKey = key + "_lastPlayed"

        // dummy values so initialization works
        self.rating = 0
        self.lastPlayed = Date()

        super.init()

        // call real loaders after initialization... must be a better way to do this
        self.rating = self.loadRating()
        self.lastPlayed = self.loadLastPlayed()
    }
}
