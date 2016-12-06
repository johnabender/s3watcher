//
//  EpisodeChooser.swift
//  s3watcher
//
//  Created by John Bender on 6/11/16.
//  Copyright © 2016 Bender Systems, LLC. All rights reserved.
//

import Foundation

private let maxDownloadedEpisodes = 10

protocol EpisodeChooserDelegate : class {
    func episodeDownloadStarted(_ monitor: DownloadProgressMonitor)
    func episodeDownloaded(_ url: URL)
    func downloadError(_ error: Error)
}

class EpisodeChooser: NSObject {
    static var sharedInstance = EpisodeChooser()

    class func sharedChooser() -> EpisodeChooser {
        return sharedInstance
    }

    var isChoosing = false

    var curGroup: String? = nil
    var ratingsURL: URL? = nil
    var episodeList: [NSDictionary]? = nil // TODO: model object instead of NSDictionary

    var delegate: EpisodeChooserDelegate? = nil

    func chooseFirstEpisode(_ group: String) {
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
                if self.episodeList != nil {
                    self.prefetchEpisodes(1, first: true)
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
                print("ratings download error:", error)
                completeAndPrefetch()
            }
        }

        Downloader.sharedDownloader().fetchListForGroup(group) { (error: Error?, list: [NSDictionary]?) -> () in
            gotEpisodes = true
            if error == nil {
                self.episodeList = list
                completeAndPrefetch()
            }
            else {
                print("list download error", error)
                self.delegate?.downloadError(error!)
            }
        }
    }

    fileprivate func downloadDir() -> URL {
        return URL(string: "file://" + (NSTemporaryDirectory() as String))!.appendingPathComponent(self.curGroup!)
    }

    fileprivate func chooseEpisodeFromList(preferLocal: Bool) -> NSDictionary {
        var episodes = self.episodeList!

        // prefer episodes already downloaded
        if preferLocal, let dir = try? FileManager.default.contentsOfDirectory(at: self.downloadDir(),
                                                                               includingPropertiesForKeys: nil,
                                                                               options: .skipsHiddenFiles) {
            episodes = []
            for file in dir {
                for potential in self.episodeList! {
                    let p = URL(string: potential["key"] as! String)!.lastPathComponent
                    if p == file.lastPathComponent {
                        episodes.append(potential)
                        break
                    }
                }
            }
            if episodes.count == 0 {
                print("no pre-downloaded files")
                episodes = self.episodeList!
            }
        }

        // TODO: choose based on ratings, if available

        let r = Int(arc4random_uniform(UInt32(episodes.count)))
        return episodes[r]
    }

    fileprivate func fetchOne(preferLocal: Bool) {
        let episode = self.chooseEpisodeFromList(preferLocal: preferLocal)
        Downloader.sharedDownloader().fetchMovie(episode, initialization: { (monitor: DownloadProgressMonitor) in
            self.delegate?.episodeDownloadStarted(monitor)
        }, completion: { (error: Error?, url: URL?) in
            if error != nil {
                print("error fetching:", error)
            }
            if url != nil {
                print("movie available at", url)
                self.delegate?.episodeDownloaded(url!)
            }
        })
    }

    func prefetchEpisodes(_ n: Int, first: Bool = false) {
        if let dir = try? FileManager.default.contentsOfDirectory(at: self.downloadDir(),
                                                                  includingPropertiesForKeys: nil,
                                                                  options: .skipsHiddenFiles) {
            if dir.count == self.episodeList!.count {
                self.fetchOne(preferLocal: true)
                return
            }
            if dir.count == maxDownloadedEpisodes {
                self.fetchOne(preferLocal: true)
                return
            }
        }


        for i in 0 ..< n {
            if Downloader.sharedDownloader().downloadingMovies.count >= Downloader.maxConcurrentDownloads {
                print("already downloading max concurrent files, not prefetching another")
                break
            }

            self.fetchOne(preferLocal: first && i == 0)
        }
    }
}
