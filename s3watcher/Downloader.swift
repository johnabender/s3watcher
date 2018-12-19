//
//  Downloader.swift
//  video-streamer
//
//  Created by John Bender on 7/3/15.
//  Copyright (c) 2015 Bender Systems, LLC. All rights reserved.
//

import Foundation

fileprivate let keyIdKey = "S3AccessKeyId"
fileprivate let secretKeyKey = "S3SecretKey"
fileprivate let bucketNameKey = "S3BucketName"

protocol DownloaderDelegate : class {
    func downloadListProgress(listCount: Int)
}

class Downloader: NSObject {
    static var shared = Downloader()

    fileprivate var bucketName: String?

    weak var delegate: DownloaderDelegate?

    class func storedCredentials() -> (String?, String?, String?) {
        return (Keychain.loadValueForKey(keyIdKey),
                Keychain.loadValueForKey(secretKeyKey),
                Keychain.loadValueForKey(bucketNameKey))
    }

    class func setStoredCredentials(accessKeyId: String, secretAccessKey: String, bucketName: String) {
        Keychain.set(value: accessKeyId, forKey: keyIdKey)
        Keychain.set(value: secretAccessKey, forKey: secretKeyKey)
        Keychain.set(value: bucketName, forKey: bucketNameKey)
    }

    func initialize(accessKeyId: String, secretAccessKey: String, bucketName: String) {
        self.bucketName = bucketName

        let credentials = AWSStaticCredentialsProvider(accessKey: accessKeyId, secretKey: secretAccessKey)
        let config = AWSServiceConfiguration(region: .usWest2, credentialsProvider: credentials)

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
                    Util.log("list exception... skipping", task.exception, f: [#file, #function])
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
                                self.delegate?.downloadListProgress(listCount: list.count)
                            }
                        }
                    }
                    if (task.result as AnyObject).isTruncated == 1, let lastObj = contents.last as? AWSS3Object {
                        Util.log("fetching another page starting with", lastObj.key, f: [#file, #function])
                        self.fetchListForGroup(group, startingList: list, marker: lastObj.key, completion: completion)
                    }
                    else {
                        completion?(nil, list)
                    }
                }
                else {
                    Util.log("no error, but no result... skipping", f: [#file, #function])
                }
            }
            return nil
        })
    }
}
