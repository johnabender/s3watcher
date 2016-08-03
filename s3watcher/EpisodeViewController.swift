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
    var waitingOnDownload = false

    override func viewDidLoad() {
        super.viewDidLoad()

        NSLog("viewdidload")
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        NSLog("1")
        objc_sync_enter(self)
        self.progressVC = storyboard.instantiateViewControllerWithIdentifier("DownloadProgressViewController") as? DownloadProgressViewController
        self.presentViewController(self.progressVC!, animated: false, completion: nil)

        waitingOnDownload = true
        objc_sync_exit(self)
        NSLog("2")
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }

    func episodeDownloadStarted() {
    }

    func episodeProgress(pct: Float64) {
        objc_sync_enter(self)
        if waitingOnDownload && self.progressVC != nil && pct > self.progressVC!.pct {
            self.progressVC!.pct = pct
        }
        objc_sync_exit(self)
    }

    func episodeDownloaded(url: NSURL) {
        NSLog("got episode, ready to start")
        objc_sync_enter(self)
        NSLog("a")
        if waitingOnDownload {
            NSLog("b")
            waitingOnDownload = false
        }
        if self.progressVC != nil {
            NSLog("c")
            NSOperationQueue.mainQueue().addOperationWithBlock({ () -> Void in
                NSLog("d")
                self.dismissViewControllerAnimated(true, completion: nil)
            })
            self.progressVC = nil
        }
        objc_sync_exit(self)
        NSLog("e")

        let item = AVPlayerItem(URL: url)
        if let p = self.avPlayerVC?.player as! AVQueuePlayer? where p.items().count > 0 {
            p.insertItem(item, afterItem: nil)
        }
        else {
            NSLog("starting player")
            NSOperationQueue.mainQueue().addOperationWithBlock({ () -> Void in
                NSLog("z")
                self.avPlayerVC = AVPlayerViewController()
                self.avPlayerVC!.player = AVQueuePlayer(items: [item])
                self.avPlayerVC!.player!.actionAtItemEnd = .Advance
                NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(EpisodeViewController.episodeFinished(_:)), name: AVPlayerItemDidPlayToEndTimeNotification, object: nil)
                self.avPlayerVC!.view.frame = self.view.bounds
                self.addChildViewController(self.avPlayerVC!)
                self.view.addSubview(self.avPlayerVC!.view)
                self.avPlayerVC!.didMoveToParentViewController(self)
                self.avPlayerVC!.player!.play()
                NSLog("y")
            })
        }
    }

    func downloadError(error: NSError) {
        var msg = error.localizedDescription
        if let userInfoMsg = error.userInfo["Message"] as? String {
            msg = userInfoMsg
        }
        let alert = UIAlertController(title: "Download error",
                                      message: msg,
                                      preferredStyle: .Alert)
        NSOperationQueue.mainQueue().addOperationWithBlock({ () -> Void in
            self.presentViewController(alert, animated: true, completion: nil)
        })
    }

    func episodeFinished(note: NSNotification) {
        NSLog("episode finished, prefetching another")
        EpisodeChooser.sharedChooser().prefetchEpisodes(1)
    }
}