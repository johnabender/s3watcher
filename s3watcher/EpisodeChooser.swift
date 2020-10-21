//
//  EpisodeChooser.swift
//  s3watcher
//
//  Created by John Bender on 6/11/16.
//  Copyright © 2016 Bender Systems, LLC. All rights reserved.
//

import Foundation

protocol EpisodeChooserDelegate : class {
    func episodeListCreated()
    func randomizingEpisodeList()
    func episodeRandomizationProgress(_ progress: Double)
    func episodeListChanged()
    func downloadError(_ error: Error)
}

class EpisodeChooser: NSObject, EpisodeListRandomizationDelegate {
    let group: String
    private let bucketName: String
    private let bucketRegion: AWSRegionType

    private(set) var list: EpisodeList
    private var baseUrl: URL

    private let isoDateFormatter: ISO8601DateFormatter

    weak var delegate: EpisodeChooserDelegate? = nil
    private var hasNotifiedDelegateOfCreation = false
    private var hasNotifiedDelegateOfFailure = false
    private var finalFailureError: Error? = nil
    private var failedDownloads = 0

    init(group: String, bucketName: String, bucketRegion: AWSRegionType) {
        self.group = group
        self.bucketName = bucketName
        self.bucketRegion = bucketRegion

        let regionString: String = {
            switch bucketRegion {
            case .usWest2: return "us-west-2"
            default: return "unknown"
            }
        }()
        self.baseUrl = URL(string: "https://s3-\(regionString).amazonaws.com/\(self.bucketName)/")!
        self.list = EpisodeList(baseUrl: self.baseUrl)

        self.isoDateFormatter = ISO8601DateFormatter()
        self.isoDateFormatter.formatOptions = .withInternetDateTime

        super.init()

        self.list.delegate = self
        self.fillList()
    }

    func ratingForEpisodeWithName(_ name: String) -> Int {
        return list.ratingForEpisodeWithName(name)
    }
    func setRatingForEpisodeWithName(_ name: String, rating: Int) {
        list.setRatingForEpisodeWithName(name, rating: rating)
        self.syncPreferences()
    }

    func lastPlayedDateForEpisodeWithName(_ name: String) -> Date {
        return list.lastPlayedDateForEpisodeWithName(name)
    }
    func setLastPlayedDateForEpisodeWithName(_ name: String, date: Date) {
        list.setLastPlayedDateForEpisodeWithName(name, date: date)
        self.syncPreferences()
    }

    private func mergeLists(authoritativeList: EpisodeList, listWithPrefs: EpisodeList) -> Bool {
        Util.log()
        // when finished, self.list should contain the merged results
        for name in authoritativeList.sortedEpisodeNames {
            authoritativeList.setRatingForEpisodeWithName(name, rating: listWithPrefs.ratingForEpisodeWithName(name))
            authoritativeList.setLastPlayedDateForEpisodeWithName(name, date: listWithPrefs.lastPlayedDateForEpisodeWithName(name))
        }
        self.list = authoritativeList

        // return true if the lists are different, meaning a play-queue update is required
        return (authoritativeList.count != listWithPrefs.count) // should test for equality, not just count
    }

    private func fillList() {
        EpisodeDatabase.shared.fetchPreferencesForGroup(group) { (error: Error?, prefs: [[String: Any]]?) -> () in
            if error != nil {
                Util.log("error fetching preferences")
                synchronized(self) {
                    self.failedDownloads += 1
                    self.finalFailureError = error
                }
                _ = self.notifyDelegateOfDownloadError()
                return
            }
            guard let episodePrefs = prefs else {
                Util.log("no error, but no preferences??")
                return
            }
            sleep(0)
            Util.log("prefs returned")

            var cacheDict: [String: [String: Any]] = [:]
            for ep in episodePrefs {
                if let key = ep["key"] as? String {
                    cacheDict[key] = ep
                }
            }

            let prefsEpisodeList = EpisodeList(baseUrl: self.baseUrl)
            prefsEpisodeList.populateFromPrefs(cacheDict, dateFormatter: self.isoDateFormatter)

            var hasChanges = false

            synchronized(self.list) {
                if self.list.count == 0 {
                    self.list = prefsEpisodeList
                }
                else {
                    hasChanges = self.mergeLists(authoritativeList: self.list, listWithPrefs: prefsEpisodeList)
                }
            }

            if hasChanges {
                self.syncPreferences()
                self.notifyDelegateOfListChanges()
            }
        }

        Downloader.shared.fetchListForGroup(group) { (error: Error?, names: [String]?) -> () in
            if error != nil {
                Util.log("list download error \(error!)")
                synchronized(self) {
                    self.failedDownloads += 1
                    self.finalFailureError = error
                }
                _ = self.notifyDelegateOfDownloadError()
                return
            }
            guard let episodeNames = names else {
                Util.log("no error but no downloaded items??")
                return
            }
            sleep(0)
            Util.log("download returned")

            // create list from names
            let downloadedEpisodeList = EpisodeList(baseUrl: self.baseUrl)
            downloadedEpisodeList.populateFromNames(episodeNames)

            var hasChanges = false

            synchronized(self.list) {
                if self.list.count == 0 {
                    self.list = downloadedEpisodeList
                }
                else {
                    hasChanges = self.mergeLists(authoritativeList: downloadedEpisodeList, listWithPrefs: self.list)
                }
            }

            if hasChanges {
                self.syncPreferences()
                self.notifyDelegateOfListChanges()
            }
        }
    }

    private func notifyDelegateOfListChanges() {
        synchronized(self) {
            if self.hasNotifiedDelegateOfCreation {
                self.delegate?.episodeListChanged()
            }
        }
    }

    private func notifyDelegateOfDownloadError() -> Bool {
        var didNotify = false

        synchronized(self) {
            if self.failedDownloads > 1,
                self.finalFailureError != nil,
                self.delegate != nil,
                !self.hasNotifiedDelegateOfFailure
            {
                self.delegate!.downloadError(self.finalFailureError!)
                self.hasNotifiedDelegateOfFailure = true
                didNotify = true
            }
        }

        return didNotify
    }

    func startCreatingEpisodeList(randomize: Bool = true, startingWith name: String? = nil) {
        if name != nil { Util.log("trying to resume with \(name!)") }

        if self.notifyDelegateOfDownloadError() {
            return
        }

        // ensure preferences have arrived
        var isWaiting = false
        synchronized(self.list) {
            if self.list.count == 0 {
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) { // why the delay?
                    self.startCreatingEpisodeList(randomize: randomize, startingWith: name)
                }
                isWaiting = true
            }
        }
        if isWaiting { return }

        // randomize and notify delegate
        if randomize {
            self.delegate?.randomizingEpisodeList()

            DispatchQueue.global().async {
                synchronized(self.list) {

                    self.list.randomize()
                    if name != nil {
                        self.list.moveNameToFront(name!)
                    }

                    synchronized(self) {
                        self.delegate?.episodeListCreated()
                        self.hasNotifiedDelegateOfCreation = true
                    }
                }
            }
        }
        else {
            synchronized(self.list) {
                synchronized(self) {
                    self.delegate?.episodeListCreated()
                    self.hasNotifiedDelegateOfCreation = true
                }
            }
        }
    }

    func syncPreferences() {
        synchronized(self.list) {
            let prefs: [[String: Any]] = self.list.map { (name, episode) in
                return ["key": episode.publicUrl.relativeString,
                        "rating": episode.rating,
                        "lastPlayed": self.isoDateFormatter.string(from: episode.lastPlayed)]
            }
            Util.log("want to sync \(prefs)")
            EpisodeDatabase.shared.setPreferencesForGroup(self.group, prefs: prefs)
        }
    }

    // MARK: - List Randomization Delegate
    func listRandomizationProgress(_ progress: Double) {
        self.delegate?.episodeRandomizationProgress(progress)
    }
}


fileprivate func synchronized(_ lock: Any, closure: () -> ()) {
    objc_sync_enter(lock)
    defer { objc_sync_exit(lock) }
    closure()
}
