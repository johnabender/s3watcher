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

    var avPlayerVC: AVPlayerViewController? = nil
    var progressVC: DownloadProgressViewController? = nil
    var waitingOnDownload = false

    override func viewDidLoad() {
        super.viewDidLoad()

        episodeChooser.delegate = self

        if let pausedGroup = UserDefaults.standard.string(forKey: pausedMovieGroupDefaultsKey) as String!,
            pausedGroup != "",
            pausedGroup == self.group,
            let pausedUrl = UserDefaults.standard.url(forKey: pausedMovieUrlDefaultsKey),
            FileManager.default.fileExists(atPath: pausedUrl.path) {

            let alert = UIAlertController(title: "Resume paused video?",
                                          message: nil,
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Resume", style: .default, handler: {(action: UIAlertAction) -> Void in
                Util.log("chose resume paused video, starting playback", f: [#file, #function])
                alert.presentingViewController?.dismiss(animated: true, completion: nil)
                self.episodeDownloaded(Episode(fileUrl: pausedUrl))
                self.clearPaused()
                self.episodeChooser.startBackgroundFetch(self.group)
            }))
            alert.addAction(UIAlertAction(title: "Ignore", style: .default, handler: {(action: UIAlertAction) -> Void in
                Util.log("chose ignore paused video, downloading another", f: [#file, #function])
                alert.presentingViewController?.dismiss(animated: true, completion: nil)
                self.clearPaused()
                self.showDownloadFirst()
            }))
            OperationQueue.main.addOperation({ () -> Void in
                self.present(alert, animated: true, completion: nil)
            })
        }
        else {
            self.showDownloadFirst()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        Util.log("will disappear", f: [#file, #function])
        self.avPlayerVC?.player?.pause()
        if let item = self.avPlayerVC?.player?.currentItem as AVPlayerItem!,
            let asset = item.asset as? AVURLAsset {

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

    func showDownloadFirst() {
        episodeChooser.startDownloads(group)

        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        objc_sync_enter(self)
        self.progressVC = storyboard.instantiateViewController(withIdentifier: "DownloadProgressViewController") as? DownloadProgressViewController
        OperationQueue.main.addOperation({ () -> Void in
            self.present(self.progressVC!, animated: false, completion: nil)
        })

        waitingOnDownload = true
        objc_sync_exit(self)
    }

    func episodeDownloadStarted(_ monitor: DownloadProgressMonitor) {
        objc_sync_enter(self)
        if waitingOnDownload && self.progressVC != nil && self.progressVC!.monitor == nil {
            self.progressVC!.monitor = monitor
        }
        else { Util.log("download started, not showing progress", f: [#file, #function]) }
        objc_sync_exit(self)
    }

    func episodeDownloaded(_ episode: Episode) {
        Util.log(episode, f: [#file, #function])
        objc_sync_enter(self)

        if waitingOnDownload {
            waitingOnDownload = false
        }
        if self.progressVC != nil {
            OperationQueue.main.addOperation({ () -> Void in
                self.dismiss(animated: true, completion: nil)
                self.progressVC = nil
            })
        }

        let item = AVPlayerItem(url: episode.fileSystemUrl)
        // if we're currently playing an episode, add new episode to the queue
        if let p = self.avPlayerVC?.player as! AVQueuePlayer? , p.items().count > 0 {
            let items = p.items()
            var foundInQueue = false
            for i in items {
                if let a = i.asset as? AVURLAsset {
                    if a.url == episode.fileSystemUrl {
                        foundInQueue = true
                        break
                    }
                }
            }
            if !foundInQueue {
                Util.log("adding to queue", f: [#file, #function])
                p.insert(item, after: nil)
            }
        }
        // not currently playing an episode, so start playback
        else {
            Util.log("starting player", f: [#file, #function])
            // if no saved time, start at 0
            let pausedTime = UserDefaults.standard.float(forKey: pausedMovieTimeDefaultsKey)
            UserDefaults.standard.set(nil, forKey: pausedMovieTimeDefaultsKey)

            self.avPlayerVC = AVPlayerViewController()
            self.avPlayerVC!.player = AVQueuePlayer(items: [item])
            self.avPlayerVC!.player!.actionAtItemEnd = .advance
            NotificationCenter.default.addObserver(self, selector: #selector(EpisodeViewController.episodeFinished(_:)), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
            OperationQueue.main.addOperation({ () -> Void in
                objc_sync_enter(self)
                self.avPlayerVC!.view.frame = self.view.bounds
                self.addChildViewController(self.avPlayerVC!)
                self.view.addSubview(self.avPlayerVC!.view)
                self.avPlayerVC!.didMove(toParentViewController: self)
                if pausedTime > 0.0 {
                    let time = CMTimeMakeWithSeconds(Float64(pausedTime), 60)
                    self.avPlayerVC!.player!.seek(to: time)
                }
                self.avPlayerVC!.player!.play()
                objc_sync_exit(self)
                Util.log("sent play", f: [#file, #function])
            })
        }

        objc_sync_exit(self)
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
        let alert = UIAlertController(title: "Download error",
                                      message: msg,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title:"OK", style:.default, handler:{(action: UIAlertAction) -> Void in
            alert.presentingViewController?.dismiss(animated: true, completion: nil)
        }))
        OperationQueue.main.addOperation({ () -> Void in
            if self.progressVC != nil && self.presentedViewController == self.progressVC {
                self.progressVC!.present(alert, animated: true, completion: nil)
            }
            else {
                self.present(alert, animated: true, completion: nil)
            }
        })
    }

    func episodeFinished(_ note: Notification) {
        if let item = self.avPlayerVC?.player?.currentItem as AVPlayerItem!,
            let asset = item.asset as? AVURLAsset {

            episodeChooser.finishedViewing(Episode(fileUrl: asset.url))
        }
        else { Util.log("unable to determine what finished", f: [#file, #function]) }
    }
}
