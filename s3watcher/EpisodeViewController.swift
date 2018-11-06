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

class EpisodeViewController: UIViewController, EpisodeChooserDelegate {
    var group: String = ""

    let episodeChooser = EpisodeChooser()
    let currentEpisode: Episode? = nil

    var avPlayerVC: AVPlayerViewController? = nil

    override func viewDidLoad() {
        super.viewDidLoad()

        self.episodeChooser.delegate = self
        self.episodeChooser.choseGroup(group)

        // TODO: handle pause/restart
        if false, let pausedGroup = UserDefaults.standard.string(forKey: pausedMovieGroupDefaultsKey),
            pausedGroup != "",
            pausedGroup == self.group {

            let alert = UIAlertController(title: "Resume paused video?",
                                          message: nil,
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Resume", style: .default, handler: {(action: UIAlertAction) -> Void in
                Util.log("chose resume paused video, starting playback", f: [#file, #function])
                self.clearPaused()
                // TODO: something
            }))
            alert.addAction(UIAlertAction(title: "Ignore", style: .default, handler: {(action: UIAlertAction) -> Void in
                Util.log("chose ignore paused video, downloading another", f: [#file, #function])
                // TODO: waiting UI
            }))
            OperationQueue.main.addOperation({ () -> Void in
                self.present(alert, animated: true, completion: nil)
            })
        }
        else {
            // TODO: waiting UI
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        Util.log(f: [#file, #function])
        self.avPlayerVC?.player?.pause()
        if let asset = self.avPlayerVC?.player?.currentItem?.asset as? AVURLAsset {
            UserDefaults.standard.set(self.group, forKey: pausedMovieGroupDefaultsKey)
            UserDefaults.standard.set(asset.url, forKey: pausedMovieUrlDefaultsKey)
            UserDefaults.standard.set(CMTimeGetSeconds(self.avPlayerVC!.player!.currentTime()), forKey: pausedMovieTimeDefaultsKey)
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
    }

    func episodeListCreated(_ episodes: [Episode]) {
        Util.log(episodes, f: [#file, #function])
        if episodes.count < 1 { return } // TODO: handle

        var items: [AVPlayerItem] = []
        for episode in episodes {
            items.append(AVPlayerItem(url: episode.publicUrl))
        }

        // if no saved time, start at 0
        let pausedTime = UserDefaults.standard.float(forKey: pausedMovieTimeDefaultsKey)
        UserDefaults.standard.set(nil, forKey: pausedMovieTimeDefaultsKey)

        NotificationCenter.default.addObserver(self, selector: #selector(EpisodeViewController.episodeFinished(_:)), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
        OperationQueue.main.addOperation({ () -> Void in
            self.avPlayerVC = AVPlayerViewController()
            self.avPlayerVC!.player = AVQueuePlayer(items: items)
            self.avPlayerVC!.player!.actionAtItemEnd = .advance
            self.avPlayerVC!.view.frame = self.view.bounds
            self.addChild(self.avPlayerVC!)
            self.view.addSubview(self.avPlayerVC!.view)
            self.avPlayerVC!.didMove(toParent: self)
            if pausedTime > 0.0 {
                let time = CMTimeMakeWithSeconds(Float64(pausedTime), preferredTimescale: 60)
                self.avPlayerVC!.player!.seek(to: time)
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

    @objc func episodeFinished(_ note: Notification) {
        if let asset = self.avPlayerVC?.player?.currentItem?.asset as? AVURLAsset {
            episodeChooser.finishedViewing(Episode(asset.url.absoluteString))
        }
        else { Util.log("unable to determine what finished", f: [#file, #function]) }
    }
}
