//
//  Keychain.swift
//  s3watcher
//
//  Created by John Bender on 12/18/18.
//  Copyright © 2018 Bender Systems, LLC. All rights reserved.
//

import Foundation
import Security

// based on https://stackoverflow.com/a/37539998/1694526
private let serviceName = "org.bendersystems.S3WatcherKeychainService"

public class Keychain: Any {

    class func set(string value: String, forKey key: String) {
        guard let dataFromString = value.data(using: String.Encoding.utf8, allowLossyConversion: false) else {
            Util.log("keychain write failed to ceate data for string: \(key)")
            return
        }

        // delete old value, else set will fail
        let deleteParameters: [NSString: Any] = [kSecClass: kSecClassGenericPassword,
                                                 kSecAttrService: serviceName,
                                                 kSecAttrAccount: key,
                                                 kSecReturnData: kCFBooleanTrue]
        let deleteStatus = SecItemDelete(deleteParameters as CFDictionary)
        if (deleteStatus != errSecSuccess), let err = SecCopyErrorMessageString(deleteStatus, nil) {
            Util.log("failed deleting from keychain: \(err)")
        }

        // set new value
        let setParameters: [NSString: Any] = [kSecClass: kSecClassGenericPassword,
                                              kSecAttrService: serviceName,
                                              kSecAttrAccount: key,
                                              kSecValueData: dataFromString]
        let setStatus = SecItemAdd(setParameters as CFDictionary, nil)

        if setStatus != errSecSuccess, let err = SecCopyErrorMessageString(setStatus, nil) {
            Util.log("failed writing to keychain: \(err)")
        }
    }

    class func loadStringForKey(_ key: String) -> String? {
        let parameters: [NSString: Any] = [kSecClass: kSecClassGenericPassword,
                                           kSecAttrService: serviceName,
                                           kSecAttrAccount: key,
                                           kSecReturnData: kCFBooleanTrue,
                                           kSecMatchLimit: kSecMatchLimitOne]
        var valueRef: AnyObject?
        let status: OSStatus = SecItemCopyMatching(parameters as CFDictionary, &valueRef)
        if status == errSecSuccess {
            if let retrievedData = valueRef as? Data {
                return String(data: retrievedData, encoding: String.Encoding.utf8)
            }
        }
        else {
            Util.log("failed reading from keychain: \(status)")
        }

        return nil
    }
}
