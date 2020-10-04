//
//  EpisodeList.swift
//  s3watcher
//
//  Created by John Bender on 2/5/19.
//  Copyright © 2019 Bender Systems, LLC. All rights reserved.
//

import Foundation

class EpisodeList : NSObject {
    private let baseUrl: URL

    private var list: [String: Episode] = [:]
    private(set) var sortedEpisodeNames: [String] = []

    var isEmpty: Bool {
        return (self.list.count == 0)
    }

    var count: Int {
        return self.list.count
    }

    init(baseUrl: URL) {
        self.baseUrl = baseUrl
        super.init()
    }

    func ratingForEpisodeWithName(_ name: String) -> Int {
        if let episode = list[name] {
            return episode.rating
        }
        return 0
    }
    func setRatingForEpisodeWithName(_ name: String, rating: Int) {
        if let episode = list[name] {
            episode.rating = rating
        }
        else { Util.log("attempting to set rating for non-existent episode named \(name)") }
    }

    func lastPlayedDateForEpisodeWithName(_ name: String) -> Date {
        if let episode = list[name] {
            return episode.lastPlayed
        }
        return Date(timeIntervalSince1970: 0)
    }
    func setLastPlayedDateForEpisodeWithName(_ name: String, date: Date) {
        if let episode = list[name] {
            episode.lastPlayed = date
        }
        else { Util.log("attempting to set last played date for non-existent episode named \(name)") }
    }

    func publicUrlForEpisodeWithName(_ name: String) -> URL {
        if let episode = list[name] {
            return episode.publicUrl
        }
        Util.log("attempting to query public URL for non-existent episode named \(name)")
        return self.baseUrl
    }

    func printableTitleForEpisodeWithName(_ name: String) -> String {
        if let episode = list[name] {
            return episode.printableTitle
        }
        Util.log("attempting to query title for non-existent episode named \(name)")
        return ""
    }

    func nameForEpisodeAtIndex(_ i: Int) -> String {
        return self.sortedEpisodeNames[i]
    }

    func enumerated() -> EnumeratedSequence<Array<String>> {
        return self.sortedEpisodeNames.enumerated()
    }

    func map<T>(_ f: (String, Episode) -> T) -> [T] { return self.list.map(f) }

    func moveNameToFront(_ name: String) {
        if let i = self.sortedEpisodeNames.firstIndex(of: name) {
            self.sortedEpisodeNames.swapAt(0, i)
        }
        else {
            Util.log("trying to move \(name) to front, but not in array")
        }
    }

    func populateFromNames(_ names: [String]) {
        self.sortedEpisodeNames = names
        self.list = Dictionary(uniqueKeysWithValues: self.sortedEpisodeNames.map {
            return ($0, Episode(baseUrl: self.baseUrl, key: $0))
        })
    }

    func populateFromPrefs(_ prefs: [String: [String: Any]], dateFormatter: ISO8601DateFormatter) {
        self.sortedEpisodeNames = Array(prefs.keys)
        self.list = Dictionary(uniqueKeysWithValues: self.sortedEpisodeNames.map {
            let episode = Episode(baseUrl: self.baseUrl, key: $0)
            if let rating = prefs[$0]?["rating"] as? Int {
                episode.rating = rating
            }
            if let lastPlayedString = prefs[$0]?["lastPlayed"] as? String,
                let lastPlayed = dateFormatter.date(from: lastPlayedString) {
                episode.lastPlayed = lastPlayed
            }
            return ($0, episode)
        })
    }

    func randomize() {
        let randomizedList = self.randomizeList(Array(self.list.values))
        self.list = Dictionary(uniqueKeysWithValues: randomizedList.map { ($0.publicUrl.relativeString, $0) })
        self.sortedEpisodeNames = randomizedList.map { $0.publicUrl.relativeString }
    }

    private func randomizeList(_ inputList: [Episode]) -> [Episode] {
        let debugRandomization = false
        if debugRandomization { Util.log("raw list: \(inputList)") }

        var candidates: [Episode] = []
        for episode in inputList {
            // initialize score based on rating
            var score = Double(episode.rating)
            if episode.rating == 0 { score = 3 }
            // weight rating based on time since last played
            if episode.lastPlayed == Date(timeIntervalSinceReferenceDate: 0) {
                score *= 10
            }
            else {
                // 1 point per year since last played, to a max of 5
                let timeFactor = max(min(round(-episode.lastPlayed.timeIntervalSinceNow/60.0/60.0/24.0/365.0), 5.0), 1.0)
                score *= timeFactor
            }

            for _ in 0..<max(1, Int(score.rounded())) {
                candidates.append(episode)
            }
            if debugRandomization { Util.log("\(episode.publicUrl.relativeString) rating \(episode.rating), last played \(episode.lastPlayed) score \(score)") }
        }
        if debugRandomization { Util.log("weighted list: \(candidates)") }

        var outputList: [Episode] = []
        while outputList.count < inputList.count {
            let match = candidates[Int(arc4random_uniform(UInt32(candidates.count)))]
            outputList.append(match)
            for i in (0..<candidates.count).reversed() {
                if candidates[i].publicUrl.absoluteURL == match.publicUrl.absoluteURL {
                    candidates.remove(at: i)
                }
            }
            if debugRandomization {
                Util.log("randomized list: \(outputList)")
                Util.log("remaining list: \(candidates)")
            }
        }

        return outputList
    }
}


class Episode : NSObject {
    private(set) var baseUrl: URL
    private(set) var name: String

    lazy var publicUrl = URL(string: self.name, relativeTo: baseUrl)!

    var rating: Int = 0
    var lastPlayed: Date = Date(timeIntervalSinceReferenceDate: 0)

    @available(*, deprecated) lazy private(set) var ratingKey = self.name + "_rating"
    @available(*, deprecated) lazy private(set) var lastPlayedKey = self.name + "_lastPlayed"

    override var description: String {
        return self.publicUrl.description
    }

    var printableTitle: String {
        return publicUrl.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "_", with: " ")
    }

    init(baseUrl: URL, key: String) {
        self.baseUrl = baseUrl
        self.name = key

        super.init()
    }
}
