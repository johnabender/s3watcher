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
            EpisodeChooser.sharedChooser().chooseEpisode(group)
        }
    }

    var avPlayerVC: AVPlayerViewController? = nil
    var progressVC: DownloadProgressViewController? = nil
    var progressMonitor: DownloadProgressMonitor? = nil
    var waitingOnDownload = false

    override func viewDidLoad() {
        super.viewDidLoad()

        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        objc_sync_enter(self)
        self.progressVC = storyboard.instantiateViewController(withIdentifier: "DownloadProgressViewController") as? DownloadProgressViewController
        self.present(self.progressVC!, animated: false, completion: nil)

        waitingOnDownload = true
        objc_sync_exit(self)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        NotificationCenter.default.removeObserver(self)
    }

    func episodeDownloadStarted() {
    }

    func episodeProgress(_ monitor: DownloadProgressMonitor) {
        objc_sync_enter(self)
        if waitingOnDownload && self.progressVC != nil && self.progressMonitor == nil && self.progressVC!.monitor == nil {
            self.progressMonitor = monitor // mostly to retain the object
            self.progressVC!.monitor = monitor
        }
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
            })
            self.progressVC = nil
        }
        objc_sync_exit(self)

        let item = AVPlayerItem(url: url)
        if let p = self.avPlayerVC?.player as! AVQueuePlayer? , p.items().count > 0 {
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
    }

    func downloadError(_ error: Error) {
        var msg = error.localizedDescription
        let nse = error as NSError
        if let userInfoMsg = nse.userInfo["Message"] as? String {
            msg = userInfoMsg
        }
        let alert = UIAlertController(title: "Download error",
                                      message: msg,
                                      preferredStyle: .alert)
        OperationQueue.main.addOperation({ () -> Void in
            self.present(alert, animated: true, completion: nil)
        })
    }

    func episodeFinished(_ note: Notification) {
        print("episode finished, prefetching another")
        EpisodeChooser.sharedChooser().prefetchEpisodes(1)
    }
}
