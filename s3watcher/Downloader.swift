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

    class func awsRegionFromRegionString(_ regionString: String) -> AWSRegionType {
        switch regionString {
        case "usw2": return .usWest2
        case "usw02": return .usWest2
        case "usw-2": return .usWest2
        case "uswest-2": return .usWest2
        case "uswest2": return .usWest2
        case "us-west-2": return .usWest2
        case "us west 2": return .usWest2
        default:
            Util.log("no match for input region \(regionString)")
            return .unknown
        }
    }

    func initialize(accessKeyId: String, secretAccessKey: String, bucketName: String, bucketRegion: String) {
        self.bucketName = bucketName

        let region = Downloader.awsRegionFromRegionString(bucketRegion)
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

    func fetchListForGroup(_ group: String, recursingList: [String] = [], recursingMarker: String = "", completion: ((Error?, [String]?)->())?) {
        guard let bucketName = self.bucketName else {
            completion?(NSError(domain: "S3DownloaderErrorDomain", code: 1, userInfo: nil), nil)
            return
        }

        let listRequest = AWSS3ListObjectsRequest()
        listRequest?.bucket = bucketName
        listRequest?.prefix = group
        listRequest?.marker = recursingMarker
        AWSS3.s3(forKey: "s3").listObjects(listRequest).continue(_: { (t: AWSTask?) -> Any? in
            guard let task = t else { return nil }

            if task.error != nil {
                completion?(task.error, nil)
            }
            else if task.exception != nil {
                Util.log("list exception... skipping \(task.exception!)")
            }
            else if task.result != nil {
                let contents : Array = (task.result as AnyObject).contents
                var list = recursingList
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
                    self.fetchListForGroup(group, recursingList: list, recursingMarker: lastObj.key, completion: completion)
                }
                else {
                    completion?(nil, list)
//                    self.cacheList(group: group, keys: list)
                }
            }
            else {
                Util.log("no error, but no result... skipping")
            }

            return nil
        })
    }

    /*
    private func cacheFileForGroup(_ group: String) -> URL {
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let cacheDir = urls.first!.appendingPathComponent("cache")
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true, attributes: nil)
        let cacheFile = cacheDir.appendingPathComponent(group).appendingPathExtension("plist")
        return cacheFile
    }

    private func cacheList(group: String, keys: [String]) {
        let cacheFile = self.cacheFileForGroup(group)
        do {
            try (keys as NSArray).write(to: cacheFile)
            Util.log("cached keys to \(cacheFile)")
        }
        catch {
            Util.log("failed writing to \(cacheFile): \(error)")
        }
    }

    private func cachedList(group: String) -> [String]? {
        let cacheFile = self.cacheFileForGroup(group)

        let expireCache = false
        if expireCache {
            // check expiration of cache
            do {
                let cacheFileAttributes = try FileManager.default.attributesOfItem(atPath: cacheFile.path)
                if let modifiedDate = cacheFileAttributes[.modificationDate] as? NSDate {
                    if modifiedDate.timeIntervalSinceNow < -60*60*24*7 {
                        Util.log("cache expired for \(group), last stored \(modifiedDate)")
                        return nil
                    }
                    // else fall through and read from file
                }
                else {
                    return nil
                }
            }
            catch {
                Util.log("failed reading file attributes for \(cacheFile): \(error)")
                return nil
            }
        }

        // read cached value
        if let cachedArray = NSArray(contentsOf: cacheFile),
            let keys = cachedArray as? [String] {
            return keys
        }

        return nil
    }
 */
}
