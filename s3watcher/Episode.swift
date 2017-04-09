//
//  Episode.swift
//  s3watcher
//
//  Created by John Bender on 12/10/16.
//  Copyright © 2016 Bender Systems, LLC. All rights reserved.
//

import Foundation

class Episode : NSObject {
    var key : String
    var size : Float64
    var fileSystemUrl: URL
    var tempDownloadUrl: URL?

    override var description: String {
        return self.fileSystemUrl.path
    }

    init(s3Key: String, fileSize: Float64) {
        self.key = s3Key
        self.size = fileSize
        self.fileSystemUrl = NSURL.fileURL(withPathComponents: [NSTemporaryDirectory(), self.key])!
        super.init()
    }

    init(fileUrl: URL) {
        self.fileSystemUrl = fileUrl
        self.size = 0.0
        if let a = try? FileManager.default.attributesOfItem(atPath: fileUrl.path) {
            let attributes = a as NSDictionary?
            if attributes != nil {
                self.size = Float64(attributes!.fileSize())
            }
        }
        self.key = fileUrl.lastPathComponent // this isn't accurate (group name?), but close enough for now
        super.init()
    }
}
