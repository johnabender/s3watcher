//
//  EpisodeDatabase.swift
//  s3watcher
//
//  Created by John Bender on 1/29/19.
//  Copyright © 2019 Bender Systems, LLC. All rights reserved.
//

import UIKit

class EpisodeDatabase: NSObject {
    static var shared = EpisodeDatabase()

    private var accessKeyId: String?
    private var bucketName: String?
    private let tableName = "s3watcher_bucket_prefs"

    func initialize(accessKeyId: String, secretAccessKey: String, bucketName: String, bucketRegion: String) {
        self.accessKeyId = accessKeyId
        self.bucketName = bucketName

        let region = Downloader.awsRegionFromRegionString(bucketRegion)
        let credentials = AWSStaticCredentialsProvider(accessKey: accessKeyId, secretKey: secretAccessKey)
        let config = AWSServiceConfiguration(region: region, credentialsProvider: credentials)

        AWSDynamoDB.register(with: config, forKey: "dynamo")
    }

    func keyForGroup(_ group: String) -> [String: AWSDynamoDBAttributeValue] {
        let bucketAttribute = AWSDynamoDBAttributeValue()
        bucketAttribute?.s = "\(self.bucketName!)/\(group)"
        let ownerAttribute = AWSDynamoDBAttributeValue()
        ownerAttribute?.s = self.accessKeyId
        return ["bucket": bucketAttribute!, "owner": ownerAttribute!]
    }

    func setPreferencesForGroup(_ group: String, prefs: [[String: Any]]) {
        let updateRequest = AWSDynamoDBUpdateItemInput()
        updateRequest?.tableName = self.tableName
        updateRequest?.key = self.keyForGroup(group)

        updateRequest?.updateExpression = "SET version = :v, prefs = :p"
        let versionAttribute = AWSDynamoDBAttributeValue()
        versionAttribute?.n = "1"
        let prefsAttribute = AWSDynamoDBAttributeValue()
        do {
            let prefsJson = try JSONSerialization.data(withJSONObject: prefs, options: [])
            if let prefsString = String(data: prefsJson, encoding: .utf8) {
                prefsAttribute?.s = prefsString
                let values: [String: AWSDynamoDBAttributeValue] = [":v": versionAttribute!, ":p": prefsAttribute!]
                updateRequest?.expressionAttributeValues = values
            }
            else {
                Util.log("failed converting JSON data to string: \(prefsJson)")
                return
            }
        }
        catch {
            Util.log("failed converting prefs to JSON: \(prefs)")
            return
        }

        AWSDynamoDB(forKey: "dynamo")?.updateItem(updateRequest)?.continue({ (t: AWSTask?) -> Any? in
            guard let task = t else { return nil }

            if task.error != nil {
                Util.log("update preferences error \(task.error!)")
            }
            else if task.exception != nil {
                Util.log("update preferences exception \(task.exception!)")
            }
            else {
                Util.log("update preferences OK")
            }

            return nil
        })
    }

    func fetchPreferencesForGroup(_ group: String, completion: ((Error?, [[String: Any]]?)->())?) {
        let getRequest = AWSDynamoDBGetItemInput()
        getRequest?.tableName = self.tableName
        getRequest?.key = self.keyForGroup(group)
        getRequest?.projectionExpression = "version, prefs"

        AWSDynamoDB(forKey: "dynamo")?.getItem(getRequest)?.continue({ (t: AWSTask?) -> Any? in
            guard let task = t else { return nil }

            if task.error != nil {
                Util.log("get preferences error \(task.error!)")
                completion?(task.error, nil)
            }
            else if task.exception != nil {
                Util.log("get preferences exception \(task.exception!)")
                completion?(NSError(domain: "S3DownloaderErrorDomain", code: 2, userInfo: nil), nil)
            }
            else if let output = task.result as? AWSDynamoDBGetItemOutput,
                let item = output.item as? [String: AWSDynamoDBAttributeValue],
                let version = item["version"],
                let prefs = item["prefs"] {
                if version.n == "1" {
                    // prefs is a JSON array:
                    //   ["key": episode.publicUrl.relativeString,
                    //    "rating": episode.rating,
                    //    "lastPlayed": self.isoDateFormatter.string(from: episode.lastPlayed)]
                    if let prefsData = prefs.s.data(using: .utf8) {
                        do {
                            let prefsObj = try JSONSerialization.jsonObject(with: prefsData, options: [])
                            if let prefsArray = prefsObj as? [[String: Any]] {
                                completion?(nil, prefsArray)
                            }
                            else {
                                Util.log("failed casting prefs object \(prefsObj)")
                                completion?(NSError(domain: "S3DownloaderErrorDomain", code: 3, userInfo: nil), nil)
                            }
                        }
                        catch {
                            Util.log("failed deserializing prefs JSON \(prefs.s.debugDescription)")
                            completion?(NSError(domain: "S3DownloaderErrorDomain", code: 3, userInfo: nil), nil)
                        }
                    }
                    else {
                        Util.log("failed getting data from prefs \(prefs)")
                        completion?(NSError(domain: "S3DownloaderErrorDomain", code: 4, userInfo: nil), nil)
                    }
                }
                else {
                    Util.log("unknown prefs version \(version)")
                    completion?(NSError(domain: "S3DownloaderErrorDomain", code: 5, userInfo: nil), nil)
                }
            }
            else {
                Util.log("failed casting prefs response \(task.result.debugDescription)")
                completion?(NSError(domain: "S3DownloaderErrorDomain", code: 6, userInfo: nil), nil)
            }

            return nil
        })
    }
}
