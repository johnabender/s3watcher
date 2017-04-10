//
//  VideoFileManager.swift
//  s3watcher
//
//  Created by John Bender on 4/8/17.
//  Copyright © 2017 Bender Systems, LLC. All rights reserved.
//

import Foundation

private let maxDownloadedEpisodes = 10
private let maxEpisodesInCache = 2

class VideoFileManager: NSObject {
    static var sharedInstance = VideoFileManager()

    class func sharedManager() -> VideoFileManager {
        return sharedInstance
    }

    var episodeCache: [Episode] = []
    var episodePrecacheQueue: [Episode] = []

    fileprivate func downloadDir(_ group: String) -> URL {
        return URL(string: "file://" + (NSTemporaryDirectory() as String))!.appendingPathComponent(group)
    }

    fileprivate func cacheDir(_ group: String) -> URL {
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return urls.first!.appendingPathComponent(group)
    }

    func warmCache(group: String) {
        func episodeSort(_ a: Episode, _ b: Episode) -> Bool {
            if let attr_a = try? FileManager.default.attributesOfItem(atPath: a.fileSystemUrl.path) as NSDictionary,
                let attr_b = try? FileManager.default.attributesOfItem(atPath: b.fileSystemUrl.path) as NSDictionary,
                let mtime_a = attr_a.fileModificationDate(),
                let mtime_b = attr_b.fileModificationDate() {

                return mtime_a < mtime_b
            }
            return false
        }

        var cachedEpisodes: [Episode] = []
        var precachedEpisodes: [Episode] = []

        if let dir = try? FileManager.default.contentsOfDirectory(at: self.cacheDir(group),
                                                                  includingPropertiesForKeys: nil,
                                                                  options: .skipsHiddenFiles) {
            for file in dir {
                cachedEpisodes.append(Episode(fileUrl: file))
            }
        }
        if let dir = try? FileManager.default.contentsOfDirectory(at: self.downloadDir(group),
                                                                  includingPropertiesForKeys: nil,
                                                                  options: .skipsHiddenFiles) {
            for file in dir {
                precachedEpisodes.append(Episode(fileUrl: file))
            }
        }

        cachedEpisodes.sort(by: episodeSort)
        precachedEpisodes.sort(by: episodeSort)

        objc_sync_enter(episodeCache)
        episodeCache = cachedEpisodes
        objc_sync_exit(episodeCache)

        objc_sync_enter(episodePrecacheQueue)
        episodePrecacheQueue = precachedEpisodes
        objc_sync_exit(episodePrecacheQueue)
    }

    fileprivate func queuedEpisode(atPosition: Int) -> Episode? {
        objc_sync_enter(episodeCache)
        if episodeCache.count > atPosition {
            let episode = episodeCache[atPosition]
            objc_sync_exit(episodeCache)
            return episode
        }
        objc_sync_exit(episodeCache)

        return nil
    }

    func firstQueuedEpisode() -> Episode? {
        return self.queuedEpisode(atPosition: 0)
    }

    func secondQueuedEpisode() -> Episode? {
        return self.queuedEpisode(atPosition: 1)
    }

    func episodeDownloaded(_ episode: Episode) -> Bool {
        objc_sync_enter(episodePrecacheQueue)
        episodePrecacheQueue.append(episode)
        objc_sync_exit(episodePrecacheQueue)

        self.tryShift()

        return episodePrecacheQueue.count < maxDownloadedEpisodes
    }

    func episodeCompleted(_ episode: Episode) {
        // Remove episode from cache, but leave on disk.
        // If this episode is selected again, the downloader will detect its
        // presence in the download directory and use the available file.
        if !self.move(episode: episode, toDir: "download") {
            // delete from disk if move failed
            try? FileManager.default.removeItem(at: episode.fileSystemUrl)
        }

        objc_sync_enter(episodeCache)
        var index = -1
        for i in 0 ..< episodeCache.count {
            if episodeCache[i].fileSystemUrl == episode.fileSystemUrl {
                index = i
                break
            }
        }
        if index == -1 {
            print("\(Date().timeIntervalSince1970) \(#file.components(separatedBy: "/").last!) \(#function) just finished playing a file that wasn't in the cache?? \(episode.fileSystemUrl)")
        } else {
            episodeCache.remove(at: index)
        }
        objc_sync_exit(episodeCache)

        self.tryShift()
    }

    // move a file from the precache to the cache, if possible
    fileprivate func tryShift() {
        if episodePrecacheQueue.count < 1 { return }
        if episodeCache.count >= maxEpisodesInCache { return }

        objc_sync_enter(episodePrecacheQueue)
        let episode = episodePrecacheQueue.remove(at: 0)
        objc_sync_exit(episodePrecacheQueue)

        _ = self.move(episode: episode, toDir: "cache")

        objc_sync_enter(episodeCache)
        episodeCache.append(episode)
        objc_sync_exit(episodeCache)
    }

    fileprivate func move(episode: Episode, toDir: String) -> Bool {
        let components = episode.fileSystemUrl.pathComponents
        let group = components[components.count - 2]
        let file = components[components.count - 1]

        var newUrl: URL
        switch (toDir) {
        case "cache":
            newUrl = self.cacheDir(group)
            break
        case "download":
            newUrl = self.downloadDir(group)
            break
        default:
            newUrl = URL(fileURLWithPath: "/tmp") // should fail silently, or not fail
        }
        try? FileManager.default.createDirectory(at: newUrl, withIntermediateDirectories: true, attributes: nil)

        newUrl.appendPathComponent(file)

        do {
            try FileManager.default.moveItem(at: episode.fileSystemUrl, to: newUrl)
            episode.fileSystemUrl = newUrl
            return true
        } catch {
            print("\(Date().timeIntervalSince1970) \(#file.components(separatedBy: "/").last!) \(#function) failed moving item from \(episode.fileSystemUrl) to \(newUrl)")
            return false
        }
    }
}
