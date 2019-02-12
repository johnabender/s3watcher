//
//  EpisodeViewController.swift
//  s3watcher
//
//  Created by John Bender on 6/11/16.
//  Copyright © 2016 Bender Systems, LLC. All rights reserved.
//

import UIKit
import AVKit

private let pausedMoviesDefaultsKey = "pausedMovieInfo"
private let pausedMovieNameKey = "pausedMovieName"
private let pausedMovieTimeKey = "pausedMovieTime"

class EpisodeViewController: UIViewController, AVPlayerViewControllerDelegate, RatingDelegate, EpisodeChooserDelegate {
    private var episodeChooser: EpisodeChooser? = nil
    private var preselectedEpisode = false

    private var avPlayerVC: AVPlayerViewController? = nil
    private var ratingVC: RatingViewController? = nil

    private var hasDisplayedProgressVC = false

    func initialize(episodeChooser: EpisodeChooser, preselectedEpisode: Bool = false) {
        self.episodeChooser = episodeChooser
        self.preselectedEpisode = preselectedEpisode
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.tryStartup()
    }

    func tryStartup() {
        if episodeChooser != nil {
            self.episodeChooser!.delegate = self

            if preselectedEpisode {
                Util.log("started with pre-selected episode")
                self.episodeListCreated()
            }
            else if let (pausedName, _) = self.loadPaused() {
                Util.log("found paused episode")
                let alert = UIAlertController(title: "Paused video detected",
                                              message: "Resume paused video, or start a new video?",
                                              preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Resume", style: .default, handler: {(action: UIAlertAction) -> Void in
                    self.episodeChooser?.createEpisodeListStartingWith(pausedName)
                    self.showProgressVC()
                }))
                alert.addAction(UIAlertAction(title: "New", style: .default, handler: {(action: UIAlertAction) -> Void in
                    self.clearPaused()
                    self.episodeChooser?.createEpisodeList()
                    self.showProgressVC()
                }))
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { (action: UIAlertAction) in
                    self.presentingViewController?.dismiss(animated: true, completion: nil)
                }))
                OperationQueue.main.addOperation({ () -> Void in
                    self.present(alert, animated: true, completion: nil)
                })
            }
            else {
                Util.log("selecting random episode")
                self.episodeChooser?.createEpisodeList()
                self.showProgressVC()
            }
        }
        else {
            // wait and try again
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
                self.tryStartup()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        self.avPlayerVC?.player?.pause()
        if let asset = self.avPlayerVC?.player?.currentItem?.asset as? AVURLAsset {
            self.setPaused(name: asset.url.relativeString, time: CMTimeGetSeconds(self.avPlayerVC!.player!.currentTime()))
            Util.log("paused video \(asset.url.relativeString)!)")
        }
        super.viewWillDisappear(animated)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        NotificationCenter.default.removeObserver(self)
    }

    // TODO: move pause data into EpisodeChooser, maybe to Dynamo?
    func loadPaused() -> (String, Float64)? {
        if let pausedData = UserDefaults.standard.dictionary(forKey: pausedMoviesDefaultsKey),
            let groupData = pausedData[self.episodeChooser!.group] as? [String: Any],
            let name = groupData[pausedMovieNameKey] as? String,
            let time = groupData[pausedMovieTimeKey] as? Float64 {
            return (name, time)
        }
        return nil
    }

    func setPaused(name: String, time: Float64) {
        let newData: [String: Any] = [pausedMovieNameKey: name,
                                      pausedMovieTimeKey: time]
        if var pausedData = UserDefaults.standard.dictionary(forKey: pausedMoviesDefaultsKey) {
            pausedData[self.episodeChooser!.group] = newData
            UserDefaults.standard.set(pausedData, forKey: pausedMoviesDefaultsKey)
        }
        else {
            let pausedData = [self.episodeChooser!.group: newData]
            UserDefaults.standard.set(pausedData, forKey: pausedMoviesDefaultsKey)
        }
    }

    func clearPaused() {
        if var pausedData = UserDefaults.standard.dictionary(forKey: pausedMoviesDefaultsKey) {
            pausedData.removeValue(forKey: self.episodeChooser!.group)
            UserDefaults.standard.set(pausedData, forKey: pausedMoviesDefaultsKey)
        }
    }

    func showProgressVC() {
        if self.avPlayerVC != nil { return }

        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let pvc = storyboard.instantiateViewController(withIdentifier: "DownloadProgressViewController") as? DownloadProgressViewController {
            Downloader.shared.progressDelegate = pvc
            OperationQueue.main.addOperation {
                if self.avPlayerVC != nil { return }

                self.present(pvc, animated: false) {
                    // presenting could take longer than the download, so check if we can dismiss immediately
                    synchronized(self) {
                        self.hasDisplayedProgressVC = true
                        if self.avPlayerVC != nil {
                            self.dismiss(animated: false) {
                                self.avPlayerVC!.player!.play()
                            }
                        }
                    }
                }
            }
        }
    }

    func itemsFromEpisodeList() -> [AVPlayerItem] {
        // create AVPlayer items from episodes
        var items: [AVPlayerItem] = []

        for (i, episodeName) in self.episodeChooser!.list.enumerated() {
            let item = AVPlayerItem(url: self.episodeChooser!.list.publicUrlForEpisodeWithName(episodeName))
            if i < self.episodeChooser!.list.count - 1 {
                // TODO: nextContentProposal
                //                let nextEpisode = episodes[i + 1]
                //                let contentProposal = AVContentProposal(contentTimeForTransition: <#T##CMTime#>, title: <#T##String#>, previewImage: <#T##UIImage?#>)
            }
            items.append(item)

            if self.preselectedEpisode {
                break
            }
        }

        return items
    }

    func newPlayerWithItems(_ items: [AVPlayerItem]) -> (AVPlayerViewController?, RatingViewController?) {
        let vc = AVPlayerViewController()
        var ratingVC: RatingViewController?

        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let rvc = storyboard.instantiateViewController(withIdentifier: "RatingViewController") as? RatingViewController {
            rvc.delegate = self
            if items.count > 0,
                let firstAsset = items[0].asset as? AVURLAsset,
                self.episodeChooser != nil {
                rvc.currentRating = self.episodeChooser!.ratingForEpisodeWithName(firstAsset.url.relativeString)
                rvc.setDefaultImagesForRating()
                rvc.episodeTitle = self.episodeChooser!.list.printableTitleForEpisodeWithName(firstAsset.url.relativeString)
            }
            vc.customInfoViewController = rvc
            ratingVC = rvc
        }
        else { Util.log("failed loading rating vc") }

        vc.delegate = self
        vc.player = AVQueuePlayer(items: items)
        vc.player!.actionAtItemEnd = .advance
        vc.skippingBehavior = .skipItem
        vc.view.frame = self.view.bounds
        self.addChild(vc)
        self.view.addSubview(vc.view)
        vc.didMove(toParent: self)

        return (vc, ratingVC)
    }

    // MARK: - Player Delegate
    @objc func episodeFinished(_ note: Notification) {
        if let asset = self.avPlayerVC?.player?.currentItem?.asset as? AVURLAsset,
            self.episodeChooser != nil {
            self.episodeChooser!.setLastPlayedDateForEpisodeWithName(asset.url.relativeString, date: Date())
        }
        if let qp = self.avPlayerVC?.player as? AVQueuePlayer {
            qp.advanceToNextItem()
            if let asset = self.avPlayerVC?.player?.currentItem?.asset as? AVURLAsset,
                self.episodeChooser != nil {
                self.ratingVC?.currentRating = self.episodeChooser!.ratingForEpisodeWithName(asset.url.relativeString)
                self.ratingVC?.episodeTitle = self.episodeChooser!.list.printableTitleForEpisodeWithName(asset.url.relativeString)
                // TODO: nextContentProposal
            }
            else if self.avPlayerVC?.player?.currentItem == nil {
                self.presentingViewController?.dismiss(animated: true, completion: nil)
            }
        }
    }

    func skipToNextItem(for playerViewController: AVPlayerViewController) {
        self.episodeFinished(Notification(name: NSNotification.Name.AVPlayerItemDidPlayToEndTime))
    }

    // MARK: - Episode Chooser Delegate
    func episodeListCreated() {
        Util.log()
        let items = self.itemsFromEpisodeList()

        if items.count < 1 {
            Util.log("created an episode list with no episodes, giving up")
            return
        }

        var pausedTime = 0.0
        if !self.preselectedEpisode,
            let (_, pt) = self.loadPaused() {

            pausedTime = pt
            self.clearPaused()
        }

        NotificationCenter.default.addObserver(self, selector: #selector(EpisodeViewController.episodeFinished(_:)), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { // delay to give progress VC time to clear
            synchronized(self) {
                (self.avPlayerVC, self.ratingVC) = self.newPlayerWithItems(items)
                if self.hasDisplayedProgressVC {
                    self.dismiss(animated: true, completion: nil)
                }

                if pausedTime > 0.0 {
                    let time = CMTimeMakeWithSeconds(Float64(pausedTime), preferredTimescale: 60)
                    self.avPlayerVC!.player!.seek(to: time)
                    Util.log("seek to \(time)")
                }
            }
            DispatchQueue.main.async {
                self.avPlayerVC!.player!.play()
            }
        }
    }

    func episodeListChanged() {
        Util.log()
        if self.avPlayerVC == nil {
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
                self.episodeListChanged()
            }
            return
        }
        synchronized(self) {
            guard let player = self.avPlayerVC?.player as? AVQueuePlayer else { return }

            let desiredItems = self.itemsFromEpisodeList()
            var desiredIndex = -1

            for (i, existingItem) in player.items().enumerated() {
                guard let existingAsset = existingItem.asset as? AVURLAsset else { return }
                if i == 0 {
                    // find starting index in desiredItems
                    for (j, desiredItem) in desiredItems.enumerated() {
                        guard let desiredAsset = desiredItem.asset as? AVURLAsset else { continue }
                        if existingAsset.url.absoluteString == desiredAsset.url.absoluteString {
                            desiredIndex = j
                            break
                        }
                    }
                    if desiredIndex < 0 {
                        Util.log("currently playing item doesn't exist in desired items, giving up")
                        return
                    }
                }
                else if desiredIndex + i >= desiredItems.count {
                    player.remove(existingItem)
                }
                else {
                    let desiredItem = desiredItems[desiredIndex + i]
                    guard let desiredAsset = desiredItem.asset as? AVURLAsset else { continue }
                    if existingAsset.url.absoluteString != desiredAsset.url.absoluteString {
                        player.remove(existingItem)
                    }
                }
            }
        }
    }

    func downloadError(_ error: Error) {
        var msg = error.localizedDescription
        let nse = error as NSError
        if let userInfoMsg = nse.userInfo["Message"] as? String {
            msg = userInfoMsg
            if let userInfoKey = nse.userInfo["Key"] as? String {
                msg += String(format: ": %@", userInfoKey)
            }
        }
        let alert = UIAlertController(title: "Initialization error",
                                      message: msg,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title:"OK", style:.default, handler:{(action: UIAlertAction) -> Void in
            alert.presentingViewController?.dismiss(animated: true, completion: nil)
        }))
        OperationQueue.main.addOperation({ () -> Void in
            self.present(alert, animated: true, completion: nil)
        })
    }

    // MARK: - Rating Delegate
    func ratingSelected(_ rating: Int) {
        Util.log("\(rating)")
        if let asset = self.avPlayerVC?.player?.currentItem?.asset as? AVURLAsset,
            self.episodeChooser != nil {
            self.episodeChooser!.setRatingForEpisodeWithName(asset.url.relativeString, rating: rating)
        }
    }
}


fileprivate func synchronized(_ lock: Any, closure: () -> ()) {
    objc_sync_enter(lock)
    defer { objc_sync_exit(lock) }
    closure()
}
