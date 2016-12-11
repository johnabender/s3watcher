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
        if var a = self.navigationController?.navigationBar.titleTextAttributes as [String: Any]! {
            a[NSForegroundColorAttributeName] = UIColor.white
            self.navigationController?.navigationBar.titleTextAttributes = a
        }

        self.initialize()
    }

    func initialize() {
        print("initializing")
        Downloader.sharedDownloader().fetchGroupList { (error: Error?, list: [String]?) in
            OperationQueue.main.addOperation({ () -> Void in
                self.spinner?.stopAnimating()
            })
            if error != nil {
                print("error fetching group list", error)
                let alert = UIAlertController(title: "Connection error",
                    message: error!.localizedDescription,
                    preferredStyle: .alert)
                alert.addAction(UIAlertAction(title:"Retry", style:.default, handler:{(action: UIAlertAction) -> Void in
                    self.dismiss(animated: true, completion: {() -> Void in
                        self.initialize()
                    })
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
        print(self.navigationController?.navigationBar.titleTextAttributes)
        print(self.navigationController?.navigationBar.barTintColor)
        print(self.navigationController?.navigationBar.tintColor)
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

