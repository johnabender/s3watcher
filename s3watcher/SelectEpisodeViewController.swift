//
//  SelectEpisodeViewController.swift
//  s3watcher
//
//  Created by John Bender on 12/19/18.
//  Copyright © 2018 Bender Systems, LLC. All rights reserved.
//

import UIKit

class SelectEpisodeViewController: UITableViewController, EpisodeChooserDelegate, UITextFieldDelegate {
    private var episodeChooser: EpisodeChooser? = nil

    private var hasDisplayedProgressVC = false

    weak var filterTextBox: UITextField? = nil
    var filteredList: [String]? = nil

    func initialize(episodeChooser: EpisodeChooser) {
        self.episodeChooser = episodeChooser
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.loadEpisodeList()
    }

    func loadEpisodeList() {
        if episodeChooser != nil {
            // initialization is complete, go for it
            self.episodeChooser!.delegate = self
            self.episodeChooser!.startCreatingEpisodeList(randomize: false)
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

    // MARK: - TableView Delegate
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch (section) {
        case 0:
            return 1
        case 1:
            if self.filteredList != nil {
                return self.filteredList!.count
            }
            return self.episodeChooser!.list.count
        default:
            return 0
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch (indexPath.section) {
        case 0:
            let cell = tableView.dequeueReusableCell(withIdentifier: "search", for: indexPath)
            for v in cell.contentView.subviews {
                if let tf = v as? UITextField {
                    self.filterTextBox = tf
                    tf.delegate = self
                }
            }
            return cell
        case 1:
            let cell = tableView.dequeueReusableCell(withIdentifier: "reuseIdentifier", for: indexPath)
            var episodeName = self.episodeChooser!.list.nameForEpisodeAtIndex((indexPath as NSIndexPath).row)
            if self.filteredList != nil {
                episodeName = self.filteredList![indexPath.row]
            }
            cell.textLabel?.text = self.episodeChooser!.list.printableTitleForEpisodeWithName(episodeName)
            return cell
        default:
            return UITableViewCell()
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch (indexPath.section) {
        case 0:
            self.filterTextBox?.select(self)
        case 1:
            if self.filterTextBox != nil,
               self.filterTextBox!.isSelected {
                Util.log("can't select an episode while filtering is open")
                return
            }

            var episodeName = self.episodeChooser!.list.nameForEpisodeAtIndex((indexPath as NSIndexPath).row)
            if self.filteredList != nil {
                episodeName = self.filteredList![indexPath.row]
            }
            Util.log("chose \(episodeName)")
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
        default:
            self.tableView.deselectRow(at: indexPath, animated: true)
        }
    }

    // MARK: - EpisodeChooser Delegate
    func episodeListCreated() {
        OperationQueue.main.addOperation {
            if self.hasDisplayedProgressVC {
                self.dismiss(animated: true, completion: nil)
            }
            self.tableView.reloadData()
        }
    }

    func randomizingEpisodeList() {}
    func episodeRandomizationProgress(_ progress: Double) {}

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

    // MARK: - TextField Delegate
    func textFieldDidEndEditing(_ textField: UITextField) {
        if !textField.hasText {
            self.filteredList = nil
        }
        else {
            self.filteredList = self.episodeChooser!.list.sortedEpisodeNames.filter {
                $0.uppercased().contains(textField.text!.uppercased())
            }
            self.tableView.reloadSections(IndexSet(integer: 1), with: .top)
        }
    }
}
