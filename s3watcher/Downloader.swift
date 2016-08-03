//
//  Downloader.swift
//  video-streamer
//
//  Created by John Bender on 7/3/15.
//  Copyright (c) 2015 Bender Systems, LLC. All rights reserved.
//

import Foundation

private let accessKeyId = ""
private let secretAccessKey = ""
private let bucketName = ""

private var once = dispatch_once_t()


class Downloader: NSObject {
    static var sharedInstance = Downloader()

    class func sharedDownloader() -> Downloader {
        return sharedInstance
    }


    override init() {
        super.init()

        dispatch_once(&once) {
            let credentials = AWSStaticCredentialsProvider(accessKey: accessKeyId, secretKey: secretAccessKey)
            let config = AWSServiceConfiguration(region: .USWest2, credentialsProvider: credentials)

            AWSS3.registerS3WithConfiguration(config, forKey: "s3")
            AWSS3TransferManager.registerS3TransferManagerWithConfiguration(config, forKey: "downloadMgr")
        }
    }

    func fetchGroupList(completion: ((NSError?, NSArray?)->())?) {
        let listRequest = AWSS3ListObjectsRequest()
        listRequest.bucket = bucketName
        listRequest.delimiter = "/"
        AWSS3.S3ForKey("s3").listObjects(listRequest).continueWithBlock { (task: AWSTask!) -> AnyObject! in
            if task.error != nil {
                completion?(task.error, nil)
            }
            if task.result != nil {
                let contents : NSArray = task.result.commonPrefixes
                let list = NSMutableArray(capacity: contents.count)
                for obj in contents {
                    if let s3obj = obj as? AWSS3CommonPrefix {
                        list.addObject(s3obj.prefix)
                    }
                }
                completion?(nil, NSArray(array: list))
            }
            return nil
        }
    }

    func fetchRatingsForGroup(group: String, completion: ((NSError?, NSURL?)->())?) {
        let downloadURL = NSURL(string: "file://" + (NSTemporaryDirectory() as NSString).stringByAppendingPathComponent("cur_ratings.txt"))

        let ratingRequest = AWSS3GetObjectRequest()
        ratingRequest.bucket = bucketName
        ratingRequest.key = group + "_ratings.txt"
        ratingRequest.downloadingFileURL = downloadURL

        AWSS3.S3ForKey("s3").getObject(ratingRequest).continueWithBlock { (task: AWSTask!) -> AnyObject! in
            if task.error != nil {
                completion?(task.error, nil)
            }
            else if task.exception != nil {
                NSLog("ratings exception %@", task.exception)
            }
            else if let output = task.result as? AWSS3GetObjectOutput, url = output.body as? NSURL {
                completion?(nil, url)
            }
            else {
                NSLog("downloaded ratings without a URL body?")
            }
            return nil
        }
    }

    func fetchListForGroup(group: String, completion: ((NSError?, NSArray?)->())?) {
        let listRequest = AWSS3ListObjectsRequest()
        listRequest.bucket = bucketName
        listRequest.prefix = group
        AWSS3.S3ForKey("s3").listObjects(listRequest).continueWithBlock { (task: AWSTask!) -> AnyObject! in
            if task.error != nil {
                completion?(task.error, nil)
            }
            else if task.exception != nil {
                NSLog("exception %@", task.exception)
            }
            else if task.result != nil {
                let contents : NSArray = task.result.contents
                let list = NSMutableArray(capacity: contents.count)
                for obj in contents {
                    if let s3obj = obj as? AWSS3Object {
                        if s3obj.size != 0 && s3obj.key != group && s3obj.key != group + "_ratings.txt" && s3obj.key != group + "_times.txt" {
                            list.addObject(["key": s3obj.key, "size": s3obj.size])
                        }
                    }
                }
                completion?(nil, NSArray(array: list))
            }
            return nil
        }
    }

    func fetchMovie(movie: NSDictionary, completion: ((NSError?, NSURL?)->())?, progress: ((pct: Float64)->())?) {
        let key = movie["key"] as! String
        let strippedMovie : NSString = (key as NSString).pathComponents.last!
        let downloadURL: NSURL = NSURL(string: "file://" + (NSTemporaryDirectory() as NSString).stringByAppendingPathComponent(strippedMovie as String))!

        // check to see if movie has already been downloaded
        if NSFileManager.defaultManager().fileExistsAtPath(downloadURL.path!) {
            NSLog("movie exists at %@", downloadURL)
            completion?(nil, downloadURL)
            return
        }

        // TODO: check to see if movie is currently being downloaded

        let transferMgr = AWSS3TransferManager.S3TransferManagerForKey("downloadMgr")
        let downloadRequest = AWSS3TransferManagerDownloadRequest()
        downloadRequest.bucket = bucketName
        downloadRequest.key = key
        downloadRequest.downloadingFileURL = downloadURL

        NSLog("starting movie download to %@", downloadURL)
        let startTime = NSDate()
        let downloadTask = transferMgr.download(downloadRequest)
        downloadTask.continueWithBlock { (task: AWSTask!) -> AnyObject! in
            NSLog("finished download in %lf min", -startTime.timeIntervalSinceNow/60.0)
            if task.error != nil {
                completion?(task.error, nil)
            }
            else if let output = task.result as? AWSS3GetObjectOutput, url = output.body as? NSURL {
                NSLog("completed OK to %@", url)
                completion?(nil, url)
            }
            return nil
        }

        if progress != nil {
            let movieSize = Float64((movie["size"] as! NSNumber).integerValue)
            let tempURL = downloadRequest.performSelector(Selector("temporaryFileURL")).takeRetainedValue() as! NSURL
            callProgress(tempURL, downloadURL: downloadURL, movieSize: movieSize, progress: progress!)
        }
    }
}

func callProgress(tempURL: NSURL, downloadURL: NSURL, movieSize: Float64, progress: ((pct: Float64)->())) {
    NSLog("prog a")
    let delayTime = dispatch_time(DISPATCH_TIME_NOW, Int64(1 * Double(NSEC_PER_SEC)))
    dispatch_after(delayTime, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)) {
        NSLog("prog b")
        if tempURL.path == nil {
            NSLog("quitting callprogress with no tempurl path")
            return
        }
        NSLog("prog c")
        if let a = try? NSFileManager.defaultManager().attributesOfItemAtPath(tempURL.path!) {
            NSLog("prog d")
            let attributes = a as NSDictionary?
            if attributes != nil {
                NSLog("prog e")
                let curSize = Float64(attributes!.fileSize())
                NSLog("%lf %@", curSize/movieSize, downloadURL)
                if curSize > 0 && curSize <= movieSize {
                    NSLog("prog f")
                    progress(pct: curSize/movieSize)
                    callProgress(tempURL, downloadURL: downloadURL, movieSize: movieSize, progress: progress)
                    NSLog("prog g")
                }
                else if curSize == 0 { NSLog("nothing yet %@", downloadURL) }
            }
            else { NSLog("attributes nil") }
        }
        else { NSLog("no attributes of item at path") }
    }
}
