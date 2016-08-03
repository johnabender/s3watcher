//
//  EpisodeChooser.swift
//  s3watcher
//
//  Created by John Bender on 6/11/16.
//  Copyright © 2016 Bender Systems, LLC. All rights reserved.
//

import Foundation

protocol EpisodeChooserDelegate : class {
    func episodeDownloadStarted()
    func episodeProgress(pct: Float64)
    func episodeDownloaded(url: NSURL)
    func downloadError(error: NSError)
}

class EpisodeChooser: NSObject {
    static var sharedInstance = EpisodeChooser()

    class func sharedChooser() -> EpisodeChooser {
        return sharedInstance
    }

    var isChoosing = false

    var curGroup: String? = nil
    var ratingsURL: NSURL? = nil
    var episodeList: NSArray? = nil

    var delegate: EpisodeChooserDelegate? = nil

    func chooseEpisode(group: String) {
        if curGroup == group {
            return
        }

        // note race condition if isChoosing
        curGroup = group
        ratingsURL = nil
        episodeList = nil

        objc_sync_enter(self)
        if isChoosing {
            objc_sync_exit(self)
            return
        }
        else {
            isChoosing = true
            objc_sync_exit(self)
        }

        var gotRatings = false
        var gotEpisodes = false

        func completeAndPrefetch() {
            if gotRatings && gotEpisodes {
                objc_sync_enter(self)
                self.isChoosing = false
                objc_sync_exit(self)
                if self.ratingsURL != nil && self.episodeList != nil {
                    self.prefetchEpisodes(1) 
                    self.delegate?.episodeDownloadStarted()
                }
            }
        }

        Downloader.sharedDownloader().fetchRatingsForGroup(group) { (error: NSError?, ratingFile: NSURL?) -> () in
            gotRatings = true
            if error == nil {
                self.ratingsURL = ratingFile
                completeAndPrefetch()
            }
            else {
                NSLog("ratings download error: %@", error!)
                self.delegate?.downloadError(error!)
            }
        }

        Downloader.sharedDownloader().fetchListForGroup(group) { (error: NSError?, list: NSArray?) -> () in
            gotEpisodes = true
            if error == nil {
                self.episodeList = list
                completeAndPrefetch()
            }
            else {
                NSLog("list download error: %@", error!)
                self.delegate?.downloadError(error!)
            }
        }
    }

    private func chooseEpisodeFromList() -> NSDictionary {
        let r = Int(arc4random_uniform(UInt32(self.episodeList!.count)) + 1)
        return self.episodeList![r] as! NSDictionary
    }

    func prefetchEpisodes(n: Int) {
        for _ in 0 ..< n {
            let episode = self.chooseEpisodeFromList()
            Downloader.sharedDownloader().fetchMovie(episode, completion: { (error: NSError?, url: NSURL?) in
                if error != nil {
                    NSLog("error fetching: %@", error!)
                }
                if url != nil {
                    NSLog("movie available at %@", url!)
                    self.delegate?.episodeDownloaded(url!)
                }
            }, progress: { (pct: Float64) in
                self.delegate?.episodeProgress(pct)
            })
        }
    }
}
