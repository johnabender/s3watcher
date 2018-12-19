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
    private var group: String
    private var episodeList: [Episode]? = nil

    weak var delegate: EpisodeChooserDelegate? = nil

    init(group: String) {
        self.group = group
        super.init()
    }

    func createEpisodeList() {
        Downloader.shared.fetchListForGroup(group) { (error: Error?, list: [String]?) -> () in
            if error == nil {
                self.delegate?.episodeListCreated(self.randomizeList(list!))
            }
            else {
                Util.log("list download error", error!, f: [#file, #function])
                self.delegate?.downloadError(error!)
            }
        }
    }

    func createEpisodeListStartingWith(url: URL) {
        let firstEpisode = Episode(group: self.group, key: url.relativePath)
        Util.log("trying to resume with", firstEpisode, f: [#file, #function])

        Downloader.shared.fetchListForGroup(group) { (error: Error?, list: [String]?) -> () in
            if error == nil {
                var episodeList = self.randomizeList(list!)
                for (i, e) in episodeList.enumerated() {
                    if e.publicUrl == firstEpisode.publicUrl {
                        episodeList.remove(at: i)
                    }
                }
                episodeList.insert(firstEpisode, at: 0)
                self.delegate?.episodeListCreated(episodeList)
            }
            else {
                Util.log("list download error", error!, f: [#file, #function])
                self.delegate?.downloadError(error!)
            }
        }
    }

    private func randomizeList(_ list: [String]) -> [Episode] {
        let debugRandomization = false
        if debugRandomization { Util.log("raw list:", list, f: [#file, #function]) }

        var candidates: [Episode] = []
        for key in list {
            let episode = Episode(group: self.group, key: key)
            var score = Double(10*max(1, episode.rating))
            let maxOldest = 60.0*60.0*24.0*365.0*2.0
            score *= min(maxOldest, -episode.lastPlayed.timeIntervalSinceNow)/maxOldest
            for _ in 0..<max(1, Int(score.rounded())) {
                candidates.append(episode)
            }
            if debugRandomization { Util.log(key, "rating", episode.rating, "last played", episode.lastPlayed, "score", score, f: [#file, #function]) }
        }
        if debugRandomization { Util.log("weighted list:", candidates, f: [#file, #function]) }

        var episodes: [Episode] = []
        while episodes.count < list.count {
            let match = candidates[Int(arc4random_uniform(UInt32(candidates.count)))]
            episodes.append(match)
            for i in (0..<candidates.count).reversed() {
                if candidates[i].publicUrl == match.publicUrl {
                    candidates.remove(at: i)
                }
            }
            if debugRandomization {
                Util.log("randomized list:", episodes, f: [#file, #function])
                Util.log("remaining list:", candidates, f: [#file, #function])
            }
        }

        return episodes
    }
}
