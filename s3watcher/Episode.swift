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
    var publicUrl: URL

    override var description: String {
        return self.publicUrl.description
    }

    init(_ key: String) {
        self.publicUrl = URL(string: key, relativeTo: baseUrl)!
        super.init()
    }
}
