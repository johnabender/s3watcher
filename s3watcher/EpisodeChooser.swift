//
//  EpisodeChooser.swift
//  s3watcher
//
//  Created by John Bender on 6/11/16.
//  Copyright © 2016 Bender Systems, LLC. All rights reserved.
//

import Foundation

protocol EpisodeChooserDelegate : class {
    func episodeDownloaded(_ episode: Episode)
    func episodeDownloadStarted(_ monitor: DownloadProgressMonitor)
    func downloadError(_ error: Error)
}

class EpisodeChooser: NSObject {
    var isChoosing = false

    var group: String? = nil
    var ratingsURL: URL? = nil
    var episodeList: [Episode]? = nil

    var delegate: EpisodeChooserDelegate? = nil

    // called when a new group is selected, initialize and kick off downloads
    func startDownloads(_ group: String) {

        // first, perform callbacks if locally cached episodes are present
        VideoFileManager.sharedManager().warmCache(group: group)
        if let episode = VideoFileManager.sharedManager().firstQueuedEpisode() {
            self.delegate?.episodeDownloaded(episode)
            if let anotherEpisode = VideoFileManager.sharedManager().secondQueuedEpisode() {
                self.delegate?.episodeDownloaded(anotherEpisode)
            }
        }

        // note race condition if isChoosing
        self.group = group
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
                if self.episodeList != nil {
                    self.prefetchEpisodes(1)
                }
            }
        }

        Downloader.sharedDownloader().fetchRatingsForGroup(group) { (error: Error?, ratingFile: URL?) -> () in
            gotRatings = true
            if error == nil {
                self.ratingsURL = ratingFile
                completeAndPrefetch()
            }
            else {
                print("ratings download error:", error!)
                completeAndPrefetch()
            }
        }

        Downloader.sharedDownloader().fetchListForGroup(group) { (error: Error?, list: [Episode]?) -> () in
            gotEpisodes = true
            if error == nil {
                self.episodeList = list
                completeAndPrefetch()
            }
            else {
                print("list download error", error!)
                self.delegate?.downloadError(error!)
            }
        }
    }

    // called when resuming a paused playback, ensure downloads are running
    func startBackgroundFetch(_ group: String) {
        self.startDownloads(group)
    }

    func finishedViewing(_ episode: Episode) {
        VideoFileManager.sharedManager().episodeCompleted(episode)
    }

    fileprivate func chooseEpisodeFromList() -> Episode {
        var episodes = self.episodeList!

        // TODO: choose based on ratings, if available
        let r = Int(arc4random_uniform(UInt32(episodes.count)))
        return episodes[r]
    }

    fileprivate func fetchOne() {
        let episode = self.chooseEpisodeFromList()
        Downloader.sharedDownloader().fetchMovie(episode, initialization: { (monitor: DownloadProgressMonitor) in
            self.delegate?.episodeDownloadStarted(monitor)
        }, completion: { (error: Error?, movie: Episode?) in
            if error != nil {
                print("error fetching:", error!)
            }
            if movie != nil {
                print("movie downloaded", movie!)
                VideoFileManager.sharedManager().episodeDownloaded(movie!)
                self.delegate?.episodeDownloaded(movie!)
            }

            self.prefetchEpisodes(2)
        })
    }

    fileprivate func prefetchEpisodes(_ n: Int) {
        for _ in 0 ..< n {
            if Downloader.sharedDownloader().downloadingMovies.count >= Downloader.maxConcurrentDownloads {
                print("already downloading max concurrent files, not prefetching another")
                break
            }

            self.fetchOne()
        }
    }
}
