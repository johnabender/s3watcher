//
//  DownloadProgressMonitor.swift
//  s3watcher
//
//  Created by John Bender on 9/4/16.
//  Copyright © 2016 Bender Systems, LLC. All rights reserved.
//

import UIKit

class DownloadProgressMonitor: NSObject {
    var tempURL: URL
    var downloadURL: URL
    var movieSize: Float64

    init(tempURL: URL, downloadURL: URL, movieSize: Float64) {
        self.tempURL = URL(string: tempURL.path)!
        self.downloadURL = downloadURL
        self.movieSize = movieSize
        super.init()
    }

    func getPctComplete() -> Float64 {
        if let a = try? FileManager.default.attributesOfItem(atPath: self.tempURL.path) {
            let attributes = a as NSDictionary?
            if attributes != nil {
                let curSize = Float64(attributes!.fileSize())
                print(curSize/self.movieSize, self.downloadURL)
                if curSize >= 0.0 && curSize <= self.movieSize {
                    return curSize/self.movieSize
                }
                else { print("not updating progress - ", curSize, movieSize) }
            }
            else { print("not continuing - no attributes") }
        }
        else { print("no item at tempurl path") }

        return 0.0
    }
}
