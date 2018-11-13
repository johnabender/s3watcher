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

    func fetchListForGroup(_ group: String, completion: ((Error?, [String]?)->())?) {

        let listRequest = AWSS3ListObjectsRequest()
        listRequest?.bucket = bucketName
        listRequest?.prefix = group
        AWSS3.s3(forKey: "s3").listObjects(listRequest).continue(_: { (t: AWSTask?) -> Any? in
            if let task = t {
                if task.error != nil {
                    completion?(task.error, nil)
                }
                else if task.exception != nil {
                    Util.log("list exception... skipping", task.exception, f: [#file, #function])
                }
                else if task.result != nil {
                    let contents : Array = (task.result as AnyObject).contents
                    var list: [String] = []
                    for obj in contents {
                        if let s3obj = obj as? AWSS3Object {
                            if s3obj.size != 0,
                                s3obj.key.hasSuffix(".m3u8"),
                                !s3obj.key.hasSuffix("-480p.m3u8")
                            {
                                list.append(s3obj.key!)
                            }
                        }
                    }
                    completion?(nil, list)
                }
                else {
                    Util.log("no error, but no result... skipping", f: [#file, #function])
                }
            }
            return nil
        })
    }
}
