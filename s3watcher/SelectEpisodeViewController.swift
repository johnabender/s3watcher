//
//  SelectEpisodeViewController.swift
//  s3watcher
//
//  Created by John Bender on 12/19/18.
//  Copyright © 2018 Bender Systems, LLC. All rights reserved.
//

import UIKit

class SelectEpisodeViewController: UITableViewController, EpisodeChooserDelegate {
    private var episodeChooser: EpisodeChooser? = nil

    private var hasDisplayedProgressVC = false

    func initialize(episodeChooser: EpisodeChooser) {
        self.episodeChooser = episodeChooser
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.loadEpisodeList()
    }

    func loadEpisodeList() {
        if episodeChooser != nil {
            self.episodeChooser!.delegate = self
            self.episodeChooser!.createEpisodeList(randomize: false)
            self.showProgressVC()
        }
        else {
            // wait and try again
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
                self.loadEpisodeList()
            }
        }
    }

    func showProgressVC() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let pvc = storyboard.instantiateViewController(withIdentifier: "DownloadProgressViewController") as? DownloadProgressViewController {
            Downloader.shared.progressDelegate = pvc
            if !self.episodeChooser!.list.isEmpty { return }
            OperationQueue.main.addOperation {
                self.present(pvc, animated: false) {
                    // presenting could take longer than the download, so check if we can dismiss immediately
                    self.hasDisplayedProgressVC = true
                    if !self.episodeChooser!.list.isEmpty {
                        self.dismiss(animated: false, completion: nil)
                    }
                }
            }
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.episodeChooser!.list.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "reuseIdentifier", for: indexPath)
        let episodeName = self.episodeChooser!.list.nameForEpisodeAtIndex((indexPath as NSIndexPath).row)
        cell.textLabel?.text = self.episodeChooser!.list.printableTitleForEpisodeWithName(episodeName)
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let episodeName = self.episodeChooser!.list.nameForEpisodeAtIndex((indexPath as NSIndexPath).row)
        self.episodeChooser!.list.moveNameToFront(episodeName)

        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let episodeVC = storyboard.instantiateViewController(withIdentifier: "EpisodeViewController") as? EpisodeViewController {
            if true {
                let parent = self.presentingViewController!
                parent.dismiss(animated: false) {
                    parent.present(episodeVC, animated: false) {
                        episodeVC.initialize(episodeChooser: self.episodeChooser!,
                                             preselectedEpisode: true)
                    }
                }
            } else {
                // this is better behavior, but AVPlayerViewController is unhappy in this scenario
                episodeVC.initialize(episodeChooser: self.episodeChooser!)
                self.present(episodeVC, animated: true, completion: nil)
            }
        }
        self.tableView.deselectRow(at: indexPath, animated: true)
    }

    func episodeListCreated() {
        OperationQueue.main.addOperation {
            if self.hasDisplayedProgressVC {
                self.dismiss(animated: true, completion: nil)
            }
            self.tableView.reloadData()
        }
    }

    func episodeListChanged() {
        OperationQueue.main.addOperation {
            self.tableView.reloadData()
        }
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
}
