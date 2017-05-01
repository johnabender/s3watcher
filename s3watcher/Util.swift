//
//  Util.swift
//  s3watcher
//
//  Created by John Bender on 5/1/17.
//  Copyright © 2017 Bender Systems, LLC. All rights reserved.
//

import Foundation

class Util: Any {
    static let dateFormatter = DateFormatter()

    class func log(_ args: Any..., f: [String] = []) {
        dateFormatter.dateFormat = "HH:mm:ss.SSS"

        var fileStr = ""
        if f.count > 0 {
            fileStr = f[0].components(separatedBy: "/").last ?? f[0]
        }
        var funcStr = ""
        if f.count > 1 {
            funcStr = f[1]
        }

        var desc = ""
        for s in args {
            desc += String(describing: s) + " "
        }

        print(dateFormatter.string(from: Date()), fileStr, funcStr, desc)
    }
}
