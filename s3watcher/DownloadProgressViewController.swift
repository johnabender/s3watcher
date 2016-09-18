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

    var startTime: Date = Date()
    var remainingStr: String = ""

    var pct: Float64 = 0.0 {
        didSet {
            if pct < 0.0 || pct > 1.0 {
                return
            }

            var remainingSec = -self.startTime.timeIntervalSinceNow*(1.0/pct - 1.0)
            var remainingMin = floor(remainingSec/60.0)
            let remainingHr = floor(remainingMin/60.0)
            remainingSec.formTruncatingRemainder(dividingBy: 60)
            remainingMin.formTruncatingRemainder(dividingBy: 60)
            if remainingHr > 0 {
                self.remainingStr = String(format: "%.lf:%02.lf:%02.lf", remainingHr, remainingMin, remainingSec)
            }
            else if remainingMin > 0 {
                self.remainingStr = String(format: "%.lf:%02.lf", remainingMin, remainingSec)
            }
            else {
                self.remainingStr = String(format: "%.lf s", remainingSec)
            }

            OperationQueue.main.addOperation({ () -> Void in
                self.progressMeter?.setProgress(Float(self.pct), animated: true)
                self.estimateLabel?.text = String(format: "%@ remaining", self.remainingStr)
            })
        }
    }

    var monitor: DownloadProgressMonitor? {
        didSet {
            monitor?.progressFunction = self.updatePct
        }
    }

    func updatePct(_ pct: Float64) {
        self.pct = pct
    }
}


