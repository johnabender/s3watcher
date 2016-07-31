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

    var groupList: NSArray = NSArray()

    override func viewDidLoad() {
        super.viewDidLoad()

        Downloader.sharedDownloader().fetchGroupList { (error: NSError?, list: NSArray?) in
            NSOperationQueue.mainQueue().addOperationWithBlock({ () -> Void in
                self.spinner?.stopAnimating()
            })
            if error != nil {
                NSLog("error fetching group list: %@", error!)
                let alert = UIAlertController(title: "Connection error",
                    message: error!.localizedDescription,
                    preferredStyle: .Alert)
                self.presentViewController(alert, animated: true, completion: nil)
            }
            if list != nil {
                self.groupList = NSArray(array: list!)
                NSOperationQueue.mainQueue().addOperationWithBlock({ () -> Void in
                    self.tableView?.reloadData()
                })
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.groupList.count
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("GroupListCell", forIndexPath: indexPath)
        cell.textLabel!.text = self.groupList[indexPath.row] as? String
        return cell
    }

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if let episodeVC = segue.destinationViewController as? EpisodeViewController,
            cell = sender as? UITableViewCell {

            let indexPath = self.tableView!.indexPathForCell(cell)! as NSIndexPath
            episodeVC.group = self.groupList[indexPath.row] as! String

            self.tableView?.deselectRowAtIndexPath(indexPath, animated: true)
        }
    }
}

