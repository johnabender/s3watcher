//
//  ViewController.swift
//  s3watcher
//
//  Created by John Bender on 11/14/15.
//  Copyright © 2015 Bender Systems, LLC. All rights reserved.
//

import UIKit

class ViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet weak var tableView: UITableView?
    @IBOutlet weak var spinner: UIActivityIndicatorView?

    var groupList: [String] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        // why doesn't the navigation bar's "title color" in the storyboard do this??
        if var a = convertFromOptionalNSAttributedStringKeyDictionary(self.navigationController?.navigationBar.titleTextAttributes) {
            a[convertFromNSAttributedStringKey(NSAttributedString.Key.foregroundColor)] = UIColor.white
            self.navigationController?.navigationBar.titleTextAttributes = convertToOptionalNSAttributedStringKeyDictionary(a)
        }

        let (accessKeyId, secretAccessKey, bucketName, bucketRegion) = Downloader.storedCredentials()
        if accessKeyId != nil, accessKeyId!.count > 0,
            secretAccessKey != nil, secretAccessKey!.count > 0,
            bucketName != nil, bucketName!.count > 0,
            bucketRegion != nil, bucketRegion!.count > 0 {
            self.initialize(accessKeyId: accessKeyId!, secretAccessKey: secretAccessKey!, bucketName: bucketName!, bucketRegion: bucketRegion!)
        }
        else {
            self.promptForCredentials(accessKeyId: accessKeyId, secretAccessKey: secretAccessKey, bucketName: bucketName, bucketRegion: bucketRegion)
        }
    }

    func initialize(accessKeyId: String, secretAccessKey: String, bucketName: String, bucketRegion: String) {
        Downloader.shared.initialize(accessKeyId: accessKeyId, secretAccessKey: secretAccessKey, bucketName: bucketName, bucketRegion: bucketRegion)
        self.fetchGroupList()
    }

    func promptForCredentials(accessKeyId: String?, secretAccessKey: String?, bucketName: String?, bucketRegion: String?) {
        let alert = UIAlertController(title: "Enter credentials",
                                      message: "To watch videos, they must be hosted in Amazon S3 and you must have proper credentials to access them.\n\nPlease enter an access key ID, a secret access key, an S3 bucket name, and the bucket's AWS region (e.g., \"us-east-1\" or \"use01\").",
                                      preferredStyle: .alert)
        alert.addTextField { (textField: UITextField) in
            textField.placeholder = "Access Key ID"
            textField.text = accessKeyId
        }
        alert.addTextField { (textField: UITextField) in
            textField.placeholder = "Secret Access Key"
            textField.text = secretAccessKey
        }
        alert.addTextField { (textField: UITextField) in
            textField.placeholder = "Bucket Name"
            textField.text = bucketName
        }
        alert.addTextField { (textField: UITextField) in
            textField.placeholder = "Bucket Region"
            textField.text = bucketRegion
        }
        alert.addAction(UIAlertAction(title: "Go", style: .default, handler:{(action: UIAlertAction) -> Void in
            self.dismiss(animated: true, completion: nil)

            var idEntry, keyEntry, bucketEntry, regionEntry: String?
            for i in 0..<alert.textFields!.count {
                switch i {
                case 0: idEntry = alert.textFields?[i].text
                case 1: keyEntry = alert.textFields?[i].text
                case 2: bucketEntry = alert.textFields?[i].text
                case 3: regionEntry = alert.textFields?[i].text
                default: break
                }
            }
            if idEntry != nil, idEntry!.count > 0,
                keyEntry != nil, keyEntry!.count > 0,
                bucketEntry != nil, bucketEntry!.count > 0,
                regionEntry != nil, regionEntry!.count > 0 {
                Util.log("saving credentials")
                Downloader.setStoredCredentials(accessKeyId: idEntry!, secretAccessKey: keyEntry!, bucketName: bucketEntry!, bucketRegion: regionEntry!)
                self.initialize(accessKeyId: idEntry!, secretAccessKey: keyEntry!, bucketName: bucketEntry!, bucketRegion: regionEntry!)
            }
            else {
                self.promptForCredentials(accessKeyId: idEntry, secretAccessKey: keyEntry, bucketName: bucketEntry, bucketRegion: bucketRegion)
            }
        }))
        OperationQueue.main.addOperation({ () -> Void in
            self.present(alert, animated: true, completion: nil)
        })
    }

    func fetchGroupList() {
        Downloader.shared.fetchGroupList { (error: Error?, list: [String]?) in
            OperationQueue.main.addOperation({ () -> Void in
                self.spinner?.stopAnimating()
            })
            if error != nil {
                Util.log("error fetching group list \(error!)")
                let alert = UIAlertController(title: "Connection error",
                    message: error!.localizedDescription,
                    preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Retry", style: .default, handler:{(action: UIAlertAction) -> Void in
                    self.dismiss(animated: true, completion: nil)
                    self.spinner?.startAnimating()
                    let (accessKeyId, secretAccessKey, bucketName, bucketRegion) = Downloader.storedCredentials()
                    self.promptForCredentials(accessKeyId: accessKeyId, secretAccessKey: secretAccessKey, bucketName: bucketName, bucketRegion: bucketRegion)
                }))
                OperationQueue.main.addOperation({ () -> Void in
                    self.present(alert, animated: true, completion: nil)
                })
            }
            else if list != nil {
                self.groupList = list!
                OperationQueue.main.addOperation({ () -> Void in
                    self.tableView?.reloadData()
                })
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.groupList.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "GroupListCell", for: indexPath)
        cell.textLabel?.text = String(self.groupList[(indexPath as NSIndexPath).row].dropLast())
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let alert = UIAlertController(title: "Random episode?",
                                      message: "Choose whether to play episodes at random, or select a single episode.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Random", style: .default, handler:{(action: UIAlertAction) -> Void in
            self.dismiss(animated: true, completion: nil)
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            if let episodeVC = storyboard.instantiateViewController(withIdentifier: "EpisodeViewController") as? EpisodeViewController {
                episodeVC.group = self.groupList[(indexPath as NSIndexPath).row]
                self.present(episodeVC, animated: true, completion: nil)
            }
        }))
        alert.addAction(UIAlertAction(title: "Select", style: .default, handler: { (action: UIAlertAction) in
            self.dismiss(animated: true, completion: nil)
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            if let selectEpisodeVC = storyboard.instantiateViewController(withIdentifier: "SelectEpisodeViewController") as? SelectEpisodeViewController {
                selectEpisodeVC.group = self.groupList[(indexPath as NSIndexPath).row]
                self.present(selectEpisodeVC, animated: true, completion: nil)
            }
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { (action: UIAlertAction) in
            self.dismiss(animated: true, completion: nil)
        }))

        self.present(alert, animated: true, completion: nil)
        self.tableView?.deselectRow(at: indexPath, animated: true)
    }
}


// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromOptionalNSAttributedStringKeyDictionary(_ input: [NSAttributedString.Key: Any]?) -> [String: Any]? {
	guard let input = input else { return nil }
	return Dictionary(uniqueKeysWithValues: input.map {key, value in (key.rawValue, value)})
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromNSAttributedStringKey(_ input: NSAttributedString.Key) -> String {
	return input.rawValue
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToOptionalNSAttributedStringKeyDictionary(_ input: [String: Any]?) -> [NSAttributedString.Key: Any]? {
	guard let input = input else { return nil }
	return Dictionary(uniqueKeysWithValues: input.map { key, value in (NSAttributedString.Key(rawValue: key), value)})
}
