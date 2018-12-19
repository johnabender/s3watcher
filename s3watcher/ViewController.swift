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

        let (accessKeyId, secretAccessKey, bucketName) = Downloader.storedCredentials()
        if accessKeyId != nil, accessKeyId!.count > 0,
            secretAccessKey != nil, secretAccessKey!.count > 0,
            bucketName != nil, bucketName!.count > 0 {
            self.initialize()
        }
        else {
            self.promptForCredentials(accessKeyId: accessKeyId, secretAccessKey: secretAccessKey, bucketName: bucketName)
        }
    }

    func initialize() {
        Util.log("initializing downloader", f: [#file, #function])
        let (accessKeyId, secretAccessKey, bucketName) = Downloader.storedCredentials()
        Downloader.shared.initialize(accessKeyId: accessKeyId!, secretAccessKey: secretAccessKey!, bucketName: bucketName!)
        self.fetchGroupList()
    }

    func promptForCredentials(accessKeyId: String?, secretAccessKey: String?, bucketName: String?) {
        let alert = UIAlertController(title: "Enter credentials",
                                      message: "To watch videos, they must be hosted in Amazon S3 and you must have proper credentials to access them.\n\nPlease enter an access key ID, a secret access key, and an S3 bucket name.",
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
        alert.addAction(UIAlertAction(title: "Go", style: .default, handler:{(action: UIAlertAction) -> Void in
            self.dismiss(animated: true, completion: nil)

            var idEntry, keyEntry, bucketEntry: String?
            for i in 0..<alert.textFields!.count {
                switch i {
                case 0: idEntry = alert.textFields?[i].text
                case 1: keyEntry = alert.textFields?[i].text
                case 2: bucketEntry = alert.textFields?[i].text
                default: break
                }
            }
            if idEntry != nil, idEntry!.count > 0,
                keyEntry != nil, keyEntry!.count > 0,
                bucketEntry != nil, bucketEntry!.count > 0 {
                Util.log("saving credentials", f: [#file, #function])
                Downloader.setStoredCredentials(accessKeyId: idEntry!, secretAccessKey: keyEntry!, bucketName: bucketEntry!)
                self.initialize()
            }
            else {
                self.promptForCredentials(accessKeyId: idEntry, secretAccessKey: keyEntry, bucketName: bucketEntry)
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
                Util.log("error fetching group list", error!, f: [#file, #function])
                let alert = UIAlertController(title: "Connection error",
                    message: error!.localizedDescription,
                    preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Retry", style: .default, handler:{(action: UIAlertAction) -> Void in
                    self.dismiss(animated: true, completion: nil)
                    self.spinner?.startAnimating()
                    let (accessKeyId, secretAccessKey, bucketName) = Downloader.storedCredentials()
                    self.promptForCredentials(accessKeyId: accessKeyId, secretAccessKey: secretAccessKey, bucketName: bucketName)
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
        cell.textLabel!.text = self.groupList[(indexPath as NSIndexPath).row]
        return cell
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let episodeVC = segue.destination as? EpisodeViewController,
            let cell = sender as? UITableViewCell {

            let indexPath = self.tableView!.indexPath(for: cell)! as IndexPath
            episodeVC.group = self.groupList[(indexPath as NSIndexPath).row]

            self.tableView?.deselectRow(at: indexPath, animated: true)
        }
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
