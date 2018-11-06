//
//  PlayerViewController.swift
//  s3watcher
//
//  Created by John Bender on 9/27/18.
//  Copyright © 2018 Bender Systems, LLC. All rights reserved.
//

import AVKit

class PlayerViewController : AVPlayerViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        let asset = AVURLAsset(url: URL(string: "http://s3-us-west-2.amazonaws.com/bender-video/simpsons/1F01-5_1-Rosebud.m3u8")!)
        let item = AVPlayerItem(asset: asset) // can init with URL, too
        self.player = AVQueuePlayer(items: [item])
        Util.log("set up player", f: [#file, #function])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        self.player!.play()
        Util.log("sent play", f: [#file, #function])
    }
}
