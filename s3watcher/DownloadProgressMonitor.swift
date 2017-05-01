//
//  DownloadProgressMonitor.swift
//  s3watcher
//
//  Created by John Bender on 9/4/16.
//  Copyright © 2016 Bender Systems, LLC. All rights reserved.
//

import UIKit

class DownloadProgressMonitor: NSObject {
    var episode: Episode

    init(episode: Episode) {
        self.episode = episode
        super.init()
    }

    func getPctComplete() -> Float64 {
        if let a = try? FileManager.default.attributesOfItem(atPath: self.episode.tempDownloadUrl!.path) {
            let attributes = a as NSDictionary?
            if attributes != nil {
                let curSize = Float64(attributes!.fileSize())
                Util.log(curSize/self.episode.size, self.episode, f: [#file, #function])
                if curSize >= 0.0 && curSize <= self.episode.size {
                    return curSize/self.episode.size
                }
                else { Util.log("not updating progress - ", curSize, self.episode.size, f: [#file, #function]) }
            }
            else { Util.log("not continuing - no attributes", f: [#file, #function]) }
        }
        else { Util.log("no item at tempurl path", f: [#file, #function]) }

        return 0.0
    }
}
