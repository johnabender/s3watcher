//
//  DownloadProgressViewController.swift
//  s3watcher
//
//  Created by John Bender on 12/18/18.
//  Copyright © 2018 Bender Systems, LLC. All rights reserved.
//

import UIKit

class DownloadProgressViewController: UIViewController, DownloaderProgressDelegate {

    @IBOutlet weak var progressLabel: UILabel?

    override func viewDidLoad() {
        super.viewDidLoad()

        self.progressLabel?.text = ""
    }

    func downloadListProgress(listCount: Int) {
        OperationQueue.main.addOperation {
            self.progressLabel?.text = "Choosing from \(listCount) episodes..."
        }
    }
}
