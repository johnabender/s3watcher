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
private let pausedMovieUrlKey = "pausedMovieUrl"
private let pausedMovieTimeKey = "pausedMovieTime"

class EpisodeViewController: UIViewController, AVPlayerViewControllerDelegate, RatingDelegate, EpisodeChooserDelegate {
    var group: String? = nil
    var episode: Episode? = nil

    var episodeChooser: EpisodeChooser? = nil

    var avPlayerVC: AVPlayerViewController? = nil
    var ratingVC: RatingViewController? = nil

    private var hasDisplayedProgressVC = false

    override func viewDidLoad() {
        super.viewDidLoad()

        self.tryStartup()
    }

    func tryStartup() {
        if group != nil {
            if episode != nil {
                Util.log("started with episode \(episode!)")
                self.episodeListCreated([episode!])
                return
            }
            Util.log("no initial episode in group \(group!)")

            self.episodeChooser = EpisodeChooser(group: group!)
            self.episodeChooser?.delegate = self

            if let (pausedUrl, _) = self.loadPaused() {
                let alert = UIAlertController(title: "Paused video detected",
                                              message: "Resume paused video, or start a new video?",
                                              preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Resume", style: .default, handler: {(action: UIAlertAction) -> Void in
                    self.episodeChooser?.createEpisodeListStartingWith(url: pausedUrl)
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
            self.setPaused(url: asset.url, time: CMTimeGetSeconds(self.avPlayerVC!.player!.currentTime()))
            Util.log("paused video \(self.episodeForItem(self.avPlayerVC?.player?.currentItem)!)")
        }
        super.viewWillDisappear(animated)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        NotificationCenter.default.removeObserver(self)
    }

    func loadPaused() -> (URL, Float64)? {
        if let pausedData = UserDefaults.standard.dictionary(forKey: pausedMoviesDefaultsKey),
            let groupData = pausedData[group!] as? [String: Any],
            let urlString = groupData[pausedMovieUrlKey] as? String,
            let url = URL(string: urlString),
            let time = groupData[pausedMovieTimeKey] as? Float64 {
            return (url, time)
        }
        return nil
    }

    func setPaused(url: URL, time: Float64) {
        let newData: [String: Any] = [pausedMovieUrlKey: url.absoluteString,
                                      pausedMovieTimeKey: time]
        if var pausedData = UserDefaults.standard.dictionary(forKey: pausedMoviesDefaultsKey) {
            pausedData[group!] = newData
            UserDefaults.standard.set(pausedData, forKey: pausedMoviesDefaultsKey)
        }
        else {
            let pausedData = [group!: newData]
            UserDefaults.standard.set(pausedData, forKey: pausedMoviesDefaultsKey)
        }
    }

    func clearPaused() {
        if var pausedData = UserDefaults.standard.dictionary(forKey: pausedMoviesDefaultsKey) {
            pausedData.removeValue(forKey: group!)
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

    func episodeForItem(_ item: AVPlayerItem?) -> Episode? {
        if let asset = item?.asset as? AVURLAsset {
            return Episode(group: group!, key: asset.url.relativeString)
        }
        return nil
    }

    func newPlayerWithItems(_ items: [AVPlayerItem]) -> (AVPlayerViewController?, RatingViewController?) {
        let vc = AVPlayerViewController()
        var ratingVC: RatingViewController?

        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let rvc = storyboard.instantiateViewController(withIdentifier: "RatingViewController") as? RatingViewController {
            let episode = self.episodeForItem(items[0])!
            rvc.delegate = self
            if items.count > 0 {
                rvc.currentRating = episode.rating
                rvc.setDefaultImagesForRating()
                rvc.episodeTitle = episode.printableTitle
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
        self.episodeForItem(self.avPlayerVC?.player?.currentItem)!.lastPlayed = Date()
        if let qp = self.avPlayerVC?.player as? AVQueuePlayer {
            qp.advanceToNextItem()
            if self.avPlayerVC?.player?.currentItem != nil {
                let newEpisode = self.episodeForItem(self.avPlayerVC?.player?.currentItem)!
                self.ratingVC?.currentRating = newEpisode.rating
                self.ratingVC?.episodeTitle = newEpisode.printableTitle
            }
        }
    }

    func skipToNextItem(for playerViewController: AVPlayerViewController) {
        self.episodeFinished(Notification(name: NSNotification.Name.AVPlayerItemDidPlayToEndTime))
    }

    // MARK: - Episode Chooser Delegate
    func episodeListCreated(_ episodes: [Episode]) {
        Util.log(episodes.description)
        if episodes.count < 1 { return } // TODO: handle

        // create AVPlayer items from episodes
        var items: [AVPlayerItem] = []
        for (i, episode) in episodes.enumerated() {
            let item = AVPlayerItem(url: episode.publicUrl)
            if i < episodes.count - 1 {
                // TODO: nextContentProposal
//                let nextEpisode = episodes[i + 1]
//                let contentProposal = AVContentProposal(contentTimeForTransition: <#T##CMTime#>, title: <#T##String#>, previewImage: <#T##UIImage?#>)
            }
            items.append(item)
        }

        var pausedTime = 0.0
        if self.episode == nil,
            let (_, pt) = self.loadPaused() {
            pausedTime = pt
            self.clearPaused()
        }

        NotificationCenter.default.addObserver(self, selector: #selector(EpisodeViewController.episodeFinished(_:)), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { // delay to give progress VC time to clear
            (self.avPlayerVC, self.ratingVC) = self.newPlayerWithItems(items)
            if self.hasDisplayedProgressVC {
                self.dismiss(animated: true, completion: nil)
            }

            if pausedTime > 0.0 {
                let time = CMTimeMakeWithSeconds(Float64(pausedTime), preferredTimescale: 60)
                self.avPlayerVC!.player!.seek(to: time)
                Util.log("seek to \(time)")
            }
            DispatchQueue.main.async {
                self.avPlayerVC!.player!.play()
            }
        }
    }

    func episodeListAppended(_ moreEpisodes: [Episode]) {
        if let player = self.avPlayerVC?.player as? AVQueuePlayer {
            Util.log(moreEpisodes.description)
            for episode in moreEpisodes {
                let item = AVPlayerItem(url: episode.publicUrl)
                // TODO: nextContentProposal for previous last item is this item
                player.insert(item, after: nil)
            }
        }
        else {
            // not playing yet, can't append, wait and try again
            // Note that if the EpisodeChooser calls this delegate function twice,
            // the episodes may get out of order as the async calls queue up.
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
                self.episodeListAppended(moreEpisodes)
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
        self.episodeForItem(self.avPlayerVC?.player?.currentItem)!.rating = rating
    }
}
