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
                if self.pct > 0.0 && self.pct < 1.0 {
                    self.estimateLabel?.text = String(format: "%@ remaining", self.remainingStr)
                }
            })
        }
    }

    var monitor: DownloadProgressMonitor? {
        didSet {
            if self.monitor != nil {
                self.startPolling()
            }
        }
    }

    var opQ: OperationQueue?

    override func viewWillDisappear(_ animated: Bool) {
        self.stopPolling()
        super.viewWillDisappear(animated)
    }

    func startPolling() {
        opQ = OperationQueue()
        self.addPollOperation()
    }

    func addPollOperation() {
        let op = BlockOperation(block: { () -> Void in })
        op.addExecutionBlock {
            if !op.isCancelled && self.monitor != nil {
                self.pct = self.monitor!.getPctComplete()
                if self.pct >= 1.0 {
                    return
                }

                let usleepTarget: useconds_t = useconds_t(1e6)
                let usleepIncrement: useconds_t = useconds_t(1e4)
                var uslept: useconds_t = 0
                while uslept < usleepTarget {
                    usleep(usleepIncrement)
                    uslept += usleepIncrement
                    if op.isCancelled {
                        return
                    }
                }
                self.addPollOperation()
            }
        }
        opQ?.addOperation(op)
    }

    func stopPolling() {
        opQ?.cancelAllOperations()
        opQ?.waitUntilAllOperationsAreFinished()
        monitor = nil
        opQ = nil
    }
}
