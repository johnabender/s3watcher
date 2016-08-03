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
            var remainingSec = -self.startTime.timeIntervalSinceNow*(1.0/pct - 1.0)
            var remainingMin = floor(remainingSec/60.0)
            let remainingHr = floor(remainingMin/60.0)
            remainingSec %= 60
            remainingMin %= 60
            if remainingHr > 0 {
                self.remainingStr = String(format: "%.lf:%02.lf:%02.lf", remainingHr, remainingMin, remainingSec)
            }
            else if remainingMin > 0 {
                self.remainingStr = String(format: "%.lf:%02.lf", remainingMin, remainingSec)
            }
            else {
                self.remainingStr = String(format: "%.lf sec", remainingSec)
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


