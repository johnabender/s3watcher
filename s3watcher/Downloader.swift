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

    
    var downloadingMovies: [Episode] = []


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

    func fetchListForGroup(_ group: String, completion: ((Error?, [Episode]?)->())?) {
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
                    var list: [Episode] = []
                    for obj in contents {
                        if let s3obj = obj as? AWSS3Object {
                            if s3obj.size != 0 && s3obj.key != group && s3obj.key != group + "_ratings.txt" && s3obj.key != group + "_times.txt" {
                                list.append(Episode(s3Key: s3obj.key, fileSize: Float64((s3obj.size).intValue)))
                            }
                        }
                    }
                    completion?(nil, list)
                }
            }
            return nil
        })
    }

    func fetchMovie(_ movie: Episode, initialization: ((_ monitor: DownloadProgressMonitor)->())?, completion: ((Error?, Episode?)->())?) {
        // check to see if movie has already been downloaded
        if FileManager.default.fileExists(atPath: movie.fileSystemUrl.path) {
            Util.log("movie exists", movie, f: [#file, #function])
            completion?(nil, movie)
            return
        }

        // check to see if movie is currently being downloaded
        if downloadingMovies.contains(movie) {
            Util.log("already downloading", movie, f: [#file, #function])
            completion?(nil, movie)
            return
        }
        downloadingMovies.append(movie)

        // ensure destination directory exists
        var downloadDir = URL(string: "file://" + NSTemporaryDirectory())!
        let components = (movie.key as NSString).pathComponents
        for c in components.prefix(components.count - 1) {
            downloadDir = downloadDir.appendingPathComponent(c)
            try? FileManager.default.createDirectory(at: downloadDir, withIntermediateDirectories: true, attributes: nil)
        }

        let transferMgr = AWSS3TransferManager.s3TransferManager(forKey: "downloadMgr")
        let downloadRequest = AWSS3TransferManagerDownloadRequest()
        downloadRequest?.bucket = bucketName
        downloadRequest?.key = movie.key
        downloadRequest?.downloadingFileURL = movie.fileSystemUrl

        Util.log("starting movie download", movie, f: [#file, #function])
        let startTime = Date()
        if let downloadTask = transferMgr?.download(downloadRequest) {
            if initialization != nil {
                movie.tempDownloadUrl = downloadRequest?.perform(Selector(("temporaryFileURL"))).takeUnretainedValue() as? URL
                let progressMonitor = DownloadProgressMonitor(episode: movie)
                initialization?(progressMonitor)
            }

            downloadTask.continue(_: { (t: AWSTask?) -> Any? in
                if let task = t {
                    Util.log("finished download in", round(-startTime.timeIntervalSinceNow/60.0), "min", f: [#file, #function])
                    if task.error != nil {
                        completion?(task.error, nil)
                    }
                    else if let output = task.result as? AWSS3GetObjectOutput, let url = output.body as? URL {
                        Util.log("completed OK to", url, f: [#file, #function])
                        completion?(nil, movie)
                    }
                    if self.downloadingMovies.index(of: movie) != nil {
                        self.downloadingMovies.remove(at: self.downloadingMovies.index(of: movie)!)
                    }
                }
                return nil
            })
        }
    }
}

