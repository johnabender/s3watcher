//
//  EpisodeViewController.swift
//  s3watcher
//
//  Created by John Bender on 6/11/16.
//  Copyright © 2016 Bender Systems, LLC. All rights reserved.
//

import UIKit
import AVKit

class EpisodeViewController: UIViewController, EpisodeChooserDelegate {
    var group: String = "" {
        didSet {
            EpisodeChooser.sharedChooser().delegate = self
            EpisodeChooser.sharedChooser().chooseFirstEpisode(group)
        }
    }

    var avPlayerVC: AVPlayerViewController? = nil
    var progressVC: DownloadProgressViewController? = nil
    var waitingOnDownload = false

    override func viewDidLoad() {
        super.viewDidLoad()

        // TODO: check if paused playback, prompt instead (also start download?)

        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        objc_sync_enter(self)
        self.progressVC = storyboard.instantiateViewController(withIdentifier: "DownloadProgressViewController") as? DownloadProgressViewController
        self.present(self.progressVC!, animated: false, completion: nil)

        waitingOnDownload = true
        objc_sync_exit(self)
    }

    override func viewWillDisappear(_ animated: Bool) {
        // TODO: pause playback, save movie name
        print("disappearing!")
        self.avPlayerVC?.player?.pause()
        if let item = self.avPlayerVC?.player?.currentItem as AVPlayerItem! {
            if let asset = item.asset as? AVURLAsset {
                print(asset.url)
            }
            print(self.avPlayerVC!.player!.currentTime())
        }
        super.viewWillDisappear(animated)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        NotificationCenter.default.removeObserver(self)
    }

    func episodeDownloadStarted(_ monitor: DownloadProgressMonitor) {
        objc_sync_enter(self)
        if waitingOnDownload && self.progressVC != nil && self.progressVC!.monitor == nil {
            self.progressVC!.monitor = monitor
        }
        else { print("download started, not showing progress") }
        objc_sync_exit(self)
    }

    func episodeDownloaded(_ url: URL) {
        print("got episode at", url, "ready to start")
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
        objc_sync_exit(self)

        let item = AVPlayerItem(url: url)
        if let p = self.avPlayerVC?.player as! AVQueuePlayer? , p.items().count > 0 {
            print("adding to queue")
            p.insert(item, after: nil)
        }
        else {
            print("starting player")
            OperationQueue.main.addOperation({ () -> Void in
                self.avPlayerVC = AVPlayerViewController()
                self.avPlayerVC!.player = AVQueuePlayer(items: [item])
                self.avPlayerVC!.player!.actionAtItemEnd = .advance
                NotificationCenter.default.addObserver(self, selector: #selector(EpisodeViewController.episodeFinished(_:)), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
                self.avPlayerVC!.view.frame = self.view.bounds
                self.addChildViewController(self.avPlayerVC!)
                self.view.addSubview(self.avPlayerVC!.view)
                self.avPlayerVC!.didMove(toParentViewController: self)
                self.avPlayerVC!.player!.play()
                print("sent play")
            })
        }

        EpisodeChooser.sharedChooser().prefetchEpisodes(2)
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
        print("episode finished, prefetching another")
        // TODO: delete downloaded episode so prefetch can proceed
        EpisodeChooser.sharedChooser().prefetchEpisodes(1)
    }
}
