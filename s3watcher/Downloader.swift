//
//  Downloader.swift
//  video-streamer
//
//  Created by John Bender on 7/3/15.
//  Copyright (c) 2015 Bender Systems, LLC. All rights reserved.
//

import Foundation

private let keyIdKey = "S3AccessKeyId"
private let secretKeyKey = "S3SecretKey"
private let bucketNameKey = "S3BucketName"
private let bucketRegionKey = "S3BucketRegion"

protocol DownloaderProgressDelegate : class {
    func downloadListProgress(listCount: Int)
}

class Downloader: NSObject {
    static var shared = Downloader()

    private var bucketName: String?

    weak var progressDelegate: DownloaderProgressDelegate?

    class func storedCredentials() -> (String?, String?, String?, String?) {
        return (Keychain.loadStringForKey(keyIdKey),
                Keychain.loadStringForKey(secretKeyKey),
                Keychain.loadStringForKey(bucketNameKey),
                Keychain.loadStringForKey(bucketRegionKey))
    }

    class func setStoredCredentials(accessKeyId: String, secretAccessKey: String, bucketName: String, bucketRegion: String) {
        Keychain.set(string: accessKeyId, forKey: keyIdKey)
        Keychain.set(string: secretAccessKey, forKey: secretKeyKey)
        Keychain.set(string: bucketName, forKey: bucketNameKey)
        Keychain.set(string: bucketRegion, forKey: bucketRegionKey)
    }

    func initialize(accessKeyId: String, secretAccessKey: String, bucketName: String, bucketRegion: String) {
        self.bucketName = bucketName

        var region = AWSRegionType.unknown
        switch bucketRegion {
        case "usw2": region = .usWest2
        case "usw02": region = .usWest2
        case "usw-2": region = .usWest2
        case "uswest-2": region = .usWest2
        case "uswest2": region = .usWest2
        case "us-west-2": region = .usWest2
        case "us west 2": region = .usWest2
        default:
            Util.log("no match for input region \(bucketRegion)")
        }

        let credentials = AWSStaticCredentialsProvider(accessKey: accessKeyId, secretKey: secretAccessKey)
        let config = AWSServiceConfiguration(region: region, credentialsProvider: credentials)

        AWSS3.register(with: config, forKey: "s3")
        AWSS3TransferManager.register(with: config, forKey: "downloadMgr")
    }

    func fetchGroupList(_ completion: ((Error?, [String]?)->())?) {
        guard let bucketName = self.bucketName else {
            completion?(NSError(domain: "S3DownloaderErrorDomain", code: 1, userInfo: nil), nil)
            return
        }

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

    func fetchListForGroup(_ group: String, startingList: [String] = [], marker: String = "", completion: ((Error?, [String]?)->())?) {
        guard let bucketName = self.bucketName else {
            completion?(NSError(domain: "S3DownloaderErrorDomain", code: 1, userInfo: nil), nil)
            return
        }

        let listRequest = AWSS3ListObjectsRequest()
        listRequest?.bucket = bucketName
        listRequest?.prefix = group
        listRequest?.marker = marker
        AWSS3.s3(forKey: "s3").listObjects(listRequest).continue(_: { (t: AWSTask?) -> Any? in
            if let task = t {
                if task.error != nil {
                    completion?(task.error, nil)
                }
                else if task.exception != nil {
                    Util.log("list exception... skipping \(task.exception!)")
                }
                else if task.result != nil {
                    let contents : Array = (task.result as AnyObject).contents
                    var list = startingList
                    for obj in contents {
                        if let s3obj = obj as? AWSS3Object {
                            if s3obj.size != 0,
                                s3obj.key.hasSuffix(".m3u8"),
                                !s3obj.key.hasSuffix("-480p.m3u8")
                            {
                                list.append(s3obj.key!)
                                self.progressDelegate?.downloadListProgress(listCount: list.count)
                            }
                        }
                    }
                    if (task.result as AnyObject).isTruncated == 1, let lastObj = contents.last as? AWSS3Object {
//                        Util.log("fetching another page starting with", lastObj.key, f: [#file, #function])
                        self.fetchListForGroup(group, startingList: list, marker: lastObj.key, completion: completion)
                    }
                    else {
                        completion?(nil, list)
                    }
                }
                else {
                    Util.log("no error, but no result... skipping")
                }
            }
            return nil
        })
    }
}
