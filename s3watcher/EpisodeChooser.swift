//
//  EpisodeChooser.swift
//  s3watcher
//
//  Created by John Bender on 6/11/16.
//  Copyright © 2016 Bender Systems, LLC. All rights reserved.
//

import Foundation

protocol EpisodeChooserDelegate : class {
    func episodeListCreated(_ episodes: [Episode])
    func downloadError(_ error: Error)
}

class EpisodeChooser: NSObject {
    fileprivate var isChoosing = false

    fileprivate var group: String? = nil
    fileprivate var episodeList: [Episode]? = nil

    var delegate: EpisodeChooserDelegate? = nil

    func choseGroup(_ group: String) {
        // note race condition if isChoosing
        self.group = group
        self.episodeList = nil

        objc_sync_enter(self)
        if isChoosing {
            objc_sync_exit(self)
            return
        }
        else {
            isChoosing = true
            objc_sync_exit(self)
        }

        Downloader.sharedDownloader().fetchListForGroup(group) { (error: Error?, list: [Episode]?) -> () in
            if error == nil {
                self.episodeList = list
                objc_sync_enter(self)
                self.isChoosing = false
                objc_sync_exit(self)
                if self.episodeList != nil {
                    self.delegate?.episodeListCreated(self.randomizeList())
                }
            }
            else {
                Util.log("list download error", error!, f: [#file, #function])
                self.delegate?.downloadError(error!)
            }
        }
    }

    func finishedViewing(_ episode: Episode) {
        // TODO: update last-played dates
        // TODO: update ratings?
        Util.log("finished", episode, f: [#file, #function])
    }

    fileprivate func randomizeList() -> [Episode] {
        // TODO: choose based on ratings, if available
        var ind: [Int] = []
        for i in 0..<self.episodeList!.count {
            ind.append(i)
        }

        var episodes: [Episode] = []
        while ind.count > 0 {
            let i = Int(arc4random_uniform(UInt32(ind.count)))
            episodes.append(self.episodeList![ind[i]])
            ind.remove(at: i)
        }

        return episodes
    }
}
