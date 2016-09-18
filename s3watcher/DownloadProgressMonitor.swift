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

    var progressFunction: (_ pct: Float64) -> ()

    let opQ = OperationQueue()

    init(tempURL: URL, downloadURL: URL, movieSize: Float64) {
        self.tempURL = URL(string: tempURL.path)!
        self.downloadURL = downloadURL
        self.movieSize = movieSize

        self.progressFunction = { (pct: Float64) -> () in }

        super.init()

        opQ.addOperation(_: {
            self.callProgress()
        })
    }

    func callProgress() {
        while true {
            print("progress sleeping")
            sleep(1)
            print("progress done sleeping, trying to check again")
            let a = try! FileManager.default.attributesOfItem(atPath: self.tempURL.path)
                let attributes = a as NSDictionary?
                if attributes != nil {
                    let curSize = Float64(attributes!.fileSize())
                    print(curSize/self.movieSize, self.downloadURL)
                    if curSize >= 0.0 && curSize <= self.movieSize {
                        self.progressFunction(curSize/self.movieSize)
                        if curSize < self.movieSize {
                            continue
                        }
                        else { print("not recursing - done") }
                    }
                    else { print("not updating progress - ", curSize) }
                }
                else { print("not continuing - no attributes") }
            break
        }
    }
    
}
