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

fileprivate let kSecClassValue = NSString(format: kSecClass)
fileprivate let kSecAttrAccountValue = NSString(format: kSecAttrAccount)
fileprivate let kSecValueDataValue = NSString(format: kSecValueData)
fileprivate let kSecClassGenericPasswordValue = NSString(format: kSecClassGenericPassword)
fileprivate let kSecAttrServiceValue = NSString(format: kSecAttrService)
fileprivate let kSecMatchLimitValue = NSString(format: kSecMatchLimit)
fileprivate let kSecReturnDataValue = NSString(format: kSecReturnData)
fileprivate let kSecMatchLimitOneValue = NSString(format: kSecMatchLimitOne)

fileprivate let serviceName = "org.bendersystems.S3WatcherKeychainService"

public class Keychain: Any {

    class func set(value: String, forKey key: String) {
        guard let dataFromString = value.data(using: String.Encoding.utf8, allowLossyConversion: false) else {
            Util.log("keychain write failed to ceate data for string:", key, f: [#file, #function])
            return
        }

        // delete old value, else set will fail
        let deleteParameters: [NSString: Any] = [kSecClassValue: kSecClassGenericPasswordValue,
                                                 kSecAttrServiceValue: serviceName,
                                                 kSecAttrAccountValue: key,
                                                 kSecReturnDataValue: kCFBooleanTrue]
        let deleteStatus = SecItemDelete(deleteParameters as CFDictionary)
        if (deleteStatus != errSecSuccess), let err = SecCopyErrorMessageString(deleteStatus, nil) {
            Util.log("failed deleting from keychain:", err, f: [#file, #function])
        }

        // set new value
        let setParameters: [NSString: Any] = [kSecClassValue: kSecClassGenericPasswordValue,
                                           kSecAttrServiceValue: serviceName,
                                           kSecAttrAccountValue: key,
                                           kSecValueDataValue: dataFromString]
        let setStatus = SecItemAdd(setParameters as CFDictionary, nil)

        if setStatus != errSecSuccess, let err = SecCopyErrorMessageString(setStatus, nil) {
            Util.log("failed writing to keychain:", err, f: [#file, #function])
        }
    }

    class func loadValueForKey(_ key: String) -> String? {
        let parameters: [NSString: Any] = [kSecClassValue: kSecClassGenericPasswordValue,
                                           kSecAttrServiceValue: serviceName,
                                           kSecAttrAccountValue: key,
                                           kSecReturnDataValue: kCFBooleanTrue,
                                           kSecMatchLimitValue: kSecMatchLimitOneValue]
        var valueRef: AnyObject?
        let status: OSStatus = SecItemCopyMatching(parameters as CFDictionary, &valueRef)
        if status == errSecSuccess {
            if let retrievedData = valueRef as? Data {
                return String(data: retrievedData, encoding: String.Encoding.utf8)
            }
        }
        else {
            Util.log("failed reading from keychain:", status, f: [#file, #function])
        }

        return nil
    }
}
