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
private let bucketName = "bender-video"

private var once = Int()


class Downloader: NSObject {
    private static var __once: () = {
        let credentials = AWSStaticCredentialsProvider(accessKey: accessKeyId, secretKey: secretAccessKey)
        let config = AWSServiceConfiguration(region: .usWest2, credentialsProvider: credentials)

        AWSS3.register(with: config, forKey: "s3")
        AWSS3TransferManager.register(with: config, forKey: "downloadMgr")
    }()
    static var sharedInstance = Downloader()

    class func sharedDownloader() -> Downloader {
        return sharedInstance
    }

    static let maxConcurrentDownloads = 5

    
    var downloadingMovies: [URL] = []


    override init() {
        super.init()

        _ = Downloader.__once
    }

    func fetchGroupList(_ completion: ((Error?, [String]?)->())?) {
        let listRequest = AWSS3ListObjectsRequest()
        listRequest?.bucket = bucketName
        listRequest?.delimiter = "/"
        AWSS3.s3(forKey: "s3").listObjects(listRequest).continue(_: { (t: AWSTask?) -> Any? in
            if let task = t {
                if task.error != nil {
                    completion?(task.error, nil)
                }
                if task.result != nil {
                    let contents : Array = (task.result as AnyObject).commonPrefixes
                    var list: [String] = []
                    list.reserveCapacity(contents.count)
                    for obj in contents {
                        if let s3obj = obj as? AWSS3CommonPrefix {
                            list.append(s3obj.prefix)
                        }
                    }
                    completion?(nil, list)
                }
            }
            return nil
        })
    }

    func fetchRatingsForGroup(_ group: String, completion: ((Error?, URL?)->())?) {
        let downloadURL = URL(string: "file://" + (NSTemporaryDirectory() as NSString).appendingPathComponent("cur_ratings.txt"))

        let ratingRequest = AWSS3GetObjectRequest()
        ratingRequest?.bucket = bucketName
        ratingRequest?.key = group + "_ratings.txt"
        ratingRequest?.downloadingFileURL = downloadURL

        AWSS3.s3(forKey: "s3").getObject(ratingRequest).continue(_: { (t: AWSTask?) -> Any? in
            if let task = t {
                if task.error != nil {
                    completion?(task.error, nil)
                }
                else if task.exception != nil {
                    NSLog("ratings exception %@", task.exception)
                }
                else if let output = task.result as? AWSS3GetObjectOutput, let url = output.body as? URL {
                    completion?(nil, url)
                }
                else {
                    NSLog("downloaded ratings without a URL body?")
                }
            }
            return nil
        })
    }

    func fetchListForGroup(_ group: String, completion: ((Error?, [NSDictionary]?)->())?) {
        let listRequest = AWSS3ListObjectsRequest()
        listRequest?.bucket = bucketName
        listRequest?.prefix = group
        AWSS3.s3(forKey: "s3").listObjects(listRequest).continue(_: { (t: AWSTask?) -> Any? in
            if let task = t {
                if task.error != nil {
                    completion?(task.error, nil)
                }
                else if task.exception != nil {
                    NSLog("exception %@", task.exception)
                }
                else if task.result != nil {
                    let contents : Array = (task.result as AnyObject).contents
                    var list: [NSDictionary] = []
                    for obj in contents {
                        if let s3obj = obj as? AWSS3Object {
                            if s3obj.size != 0 && s3obj.key != group && s3obj.key != group + "_ratings.txt" && s3obj.key != group + "_times.txt" {
                                // TODO: make model object
                                list.append(["key": s3obj.key, "size": s3obj.size])
                            }
                        }
                    }
                    completion?(nil, list)
                }
            }
            return nil
        })
    }

    func fetchMovie(_ movie: NSDictionary, initialization: ((_ monitor: DownloadProgressMonitor)->())?, completion: ((Error?, URL?)->())?) {
        let key = movie["key"] as! String
        let downloadURL: URL = URL(string: "file://" + (NSTemporaryDirectory() as NSString).appendingPathComponent(key))!

        // check to see if movie has already been downloaded
        if FileManager.default.fileExists(atPath: downloadURL.path) {
            print("movie exists at", downloadURL)
            completion?(nil, downloadURL)
            return
        }

        // check to see if movie is currently being downloaded
        if downloadingMovies.contains(downloadURL) {
            print("already downloading", downloadURL)
            completion?(nil, downloadURL)
            return
        }
        downloadingMovies.append(downloadURL)

        // ensure destination directory exists
        var downloadDir = URL(string: "file://" + NSTemporaryDirectory())!
        let components = (key as NSString).pathComponents
        for c in components.prefix(components.count - 1) {
            downloadDir = downloadDir.appendingPathComponent(c)
        }
        try? FileManager.default.createDirectory(at: downloadDir, withIntermediateDirectories: true, attributes: nil)

        let transferMgr = AWSS3TransferManager.s3TransferManager(forKey: "downloadMgr")
        let downloadRequest = AWSS3TransferManagerDownloadRequest()
        downloadRequest?.bucket = bucketName
        downloadRequest?.key = key
        downloadRequest?.downloadingFileURL = downloadURL

        print("starting movie download to", downloadURL)
        let startTime = Date()
        if let downloadTask = transferMgr?.download(downloadRequest) {
            if initialization != nil {
                let movieSize = Float64((movie["size"] as! NSNumber).intValue)
                let tempURL = downloadRequest?.perform(Selector(("temporaryFileURL"))).takeUnretainedValue() as! URL
                let progressMonitor = DownloadProgressMonitor(tempURL: tempURL, downloadURL: downloadURL, movieSize: movieSize)
                initialization?(progressMonitor)
            }

            downloadTask.continue(_: { (t: AWSTask?) -> Any? in
                if let task = t {
                    print("finished download in", round(-startTime.timeIntervalSinceNow/60.0), "min")
                    if task.error != nil {
                        completion?(task.error, nil)
                    }
                    else if let output = task.result as? AWSS3GetObjectOutput, let url = output.body as? URL {
                        print("completed OK to", url)
                        completion?(nil, url)
                    }
                    if self.downloadingMovies.index(of: downloadURL) != nil {
                        self.downloadingMovies.remove(at: self.downloadingMovies.index(of: downloadURL)!)
                    }
                }
                return nil
            })
        }
    }
}

