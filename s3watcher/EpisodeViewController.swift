//
//  EpisodeViewController.swift
//  s3watcher
//
//  Created by John Bender on 6/11/16.
//  Copyright © 2016 Bender Systems, LLC. All rights reserved.
//

import UIKit
import AVKit

private let pausedMovieGroupDefaultsKey = "pausedMovieGroup"
private let pausedMovieUrlDefaultsKey = "pausedMovieUrl"
private let pausedMovieTimeDefaultsKey = "pausedMovieTime"

class EpisodeViewController: UIViewController, AVPlayerViewControllerDelegate, RatingDelegate, EpisodeChooserDelegate {
    var group: String = ""

    var episodeChooser: EpisodeChooser? = nil
    var avPlayerVC: AVPlayerViewController? = nil

    var ratingVC: RatingViewController? = nil

    override func viewDidLoad() {
        super.viewDidLoad()

        self.episodeChooser = EpisodeChooser(group: group)
        self.episodeChooser?.delegate = self

        if let pausedGroup = UserDefaults.standard.string(forKey: pausedMovieGroupDefaultsKey),
            pausedGroup != "",
            pausedGroup == self.group {

            let alert = UIAlertController(title: "Resume paused video?",
                                          message: nil,
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Resume", style: .default, handler: {(action: UIAlertAction) -> Void in
                let pausedUrl = UserDefaults.standard.url(forKey: pausedMovieUrlDefaultsKey)!
                self.episodeChooser?.createEpisodeListStartingWith(url: pausedUrl)
                self.showProgressVC()
            }))
            alert.addAction(UIAlertAction(title: "Ignore", style: .default, handler: {(action: UIAlertAction) -> Void in
                self.clearPaused()
                self.episodeChooser?.createEpisodeList()
                self.showProgressVC()
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

    override func viewWillDisappear(_ animated: Bool) {
        self.avPlayerVC?.player?.pause()
        if let asset = self.avPlayerVC?.player?.currentItem?.asset as? AVURLAsset {
            UserDefaults.standard.set(self.group, forKey: pausedMovieGroupDefaultsKey)
            UserDefaults.standard.set(asset.url, forKey: pausedMovieUrlDefaultsKey)
            UserDefaults.standard.set(CMTimeGetSeconds(self.avPlayerVC!.player!.currentTime()), forKey: pausedMovieTimeDefaultsKey)
            Util.log("paused video", self.episodeForItem(self.avPlayerVC?.player?.currentItem), f: [#file, #function])
        }
        super.viewWillDisappear(animated)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        NotificationCenter.default.removeObserver(self)
    }

    func clearPaused() {
        UserDefaults.standard.set(nil, forKey: pausedMovieGroupDefaultsKey)
        UserDefaults.standard.set(nil, forKey: pausedMovieUrlDefaultsKey)
        UserDefaults.standard.set(nil, forKey: pausedMovieTimeDefaultsKey)
    }

    func showProgressVC() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let pvc = storyboard.instantiateViewController(withIdentifier: "DownloadProgressViewController") as? DownloadProgressViewController {
            Downloader.shared.delegate = pvc
            self.present(pvc, animated: true, completion: nil)
        }
    }

    func episodeForItem(_ item: AVPlayerItem?) -> Episode {
        if let asset = item?.asset as? AVURLAsset {
            return Episode(group: self.group, key: asset.url.relativeString)
        }
        return Episode(group: self.group, key: "fake-url")
    }

    func newPlayerWithItems(_ items: [AVPlayerItem]) -> (AVPlayerViewController?, RatingViewController?) {
        let vc = AVPlayerViewController()
        var ratingVC: RatingViewController?

        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let rvc = storyboard.instantiateViewController(withIdentifier: "RatingViewController") as? RatingViewController {
            let episode = self.episodeForItem(items[0])
            rvc.delegate = self
            if items.count > 0 {
                rvc.currentRating = episode.rating
                rvc.setDefaultImagesForRating()
                rvc.episodeTitle = episode.publicUrl.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "_", with: " ")
            }
            vc.customInfoViewController = rvc
            ratingVC = rvc
        }
        else { Util.log("failed loading rating vc", f: [#file, #function]) }

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
        self.episodeForItem(self.avPlayerVC?.player?.currentItem).lastPlayed = Date()
        if let qp = self.avPlayerVC?.player as? AVQueuePlayer {
            qp.advanceToNextItem()
            self.ratingVC?.currentRating = self.episodeForItem(self.avPlayerVC?.player?.currentItem).rating
        }
    }

    func skipToNextItem(for playerViewController: AVPlayerViewController) {
        self.episodeFinished(Notification(name: NSNotification.Name.AVPlayerItemDidPlayToEndTime))
    }

    // MARK: - Episode Chooser Delegate
    func episodeListCreated(_ episodes: [Episode]) {
        self.dismiss(animated: true, completion: nil)
        Util.log(episodes, f: [#file, #function])
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

        let pausedTime = UserDefaults.standard.float(forKey: pausedMovieTimeDefaultsKey)
        self.clearPaused()

        NotificationCenter.default.addObserver(self, selector: #selector(EpisodeViewController.episodeFinished(_:)), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
        OperationQueue.main.addOperation({ () -> Void in
            (self.avPlayerVC, self.ratingVC) = self.newPlayerWithItems(items)

            if pausedTime > 0.0 {
                let time = CMTimeMakeWithSeconds(Float64(pausedTime), preferredTimescale: 60)
                self.avPlayerVC!.player!.seek(to: time)
                Util.log("seek to", time, f: [#file, #function])
            }
            self.avPlayerVC!.player!.play()
        })
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
        Util.log(rating, f: [#file, #function])
        self.episodeForItem(self.avPlayerVC?.player?.currentItem).rating = rating
    }
}
