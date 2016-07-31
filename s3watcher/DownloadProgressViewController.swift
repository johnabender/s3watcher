//
//  DownloadProgressViewController.swift
//  s3watcher
//
//  Created by John Bender on 7/29/16.
//  Copyright © 2016 Bender Systems, LLC. All rights reserved.
//

import UIKit

class DownloadProgressViewController: UIViewController {
    @IBOutlet weak var progressMeter: UIProgressView?
    @IBOutlet weak var estimateLabel: UILabel?

    var pct: Float64 = 0.0 {
        didSet {
            var remaining = -self.startTime.timeIntervalSinceNow*(1.0/pct - 1.0)
            var interval: String = "sec"
            if remaining > 60.0 {
                remaining /= 60.0
                interval = "min"
            }
            if remaining > 60.0 {
                remaining /= 60.0
                interval = "hr"
            }
            self.remainingStr = String(format: "%.1lf %@", remaining, interval)
            if interval == "sec" {
                self.remainingStr = String(format: "%.lf %@", remaining, interval)
            }

            NSOperationQueue.mainQueue().addOperationWithBlock({ () -> Void in
                self.progressMeter?.setProgress(Float(self.pct), animated: true)
                self.estimateLabel?.text = String(format: "%@ remaining", self.remainingStr)
            })
        }
    }

    var startTime: NSDate = NSDate()
    var remainingStr: String = ""
}


