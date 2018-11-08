//
//  RatingViewController.swift
//  s3watcher
//
//  Created by John Bender on 11/6/18.
//  Copyright © 2018 Bender Systems, LLC. All rights reserved.
//

import UIKit

protocol RatingDelegate : class {
    func ratingSelected(_ rating: Int)
}

class RatingViewController: UIViewController {
    @IBOutlet weak var button1: UIButton?
    @IBOutlet weak var button2: UIButton?
    @IBOutlet weak var button3: UIButton?
    @IBOutlet weak var button4: UIButton?
    @IBOutlet weak var button5: UIButton?

    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        Util.log(f: [#file, #function]) // not called! :(
        if self.button1 != nil && self.button2 != nil && self.button3 != nil && self.button4 != nil && self.button5 != nil {
            Util.log(f: [#file, #function])
            return [self.button1!, self.button2!, self.button3!, self.button4!, self.button5!]
        }
        return []
    }

    var currentRating = 0

    fileprivate let emptyImg = UIImage(named: "RatingStarEmpty")
    fileprivate let filledImg = UIImage(named: "RatingStarFilled")

    var delegate: RatingDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()

        self.preferredContentSize = CGSize(width: 0, height: 200) // width is auto-set

        self.setDefaultImagesForRating()
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)

        self.emptyAllImages()

        switch context.nextFocusedView {
        case nil: return
        case self.button1:
            Util.log("button 1", f: [#file, #function])
        case self.button2:
            Util.log("button 2", f: [#file, #function])
            self.setFilledImagesForButtonsThrough(1)
        case self.button3:
            Util.log("button 3", f: [#file, #function])
            self.setFilledImagesForButtonsThrough(2)
        case self.button4:
            Util.log("button 4", f: [#file, #function])
            self.setFilledImagesForButtonsThrough(3)
        case self.button5:
            Util.log("button 5", f: [#file, #function])
            self.setFilledImagesForButtonsThrough(4)
        default:
            self.setDefaultImagesForRating()
            Util.log("some other focus", f: [#file, #function])
        }
    }

    func emptyAllImages() {
        self.button1?.setBackgroundImage(emptyImg, for: .normal)
        self.button2?.setBackgroundImage(emptyImg, for: .normal)
        self.button3?.setBackgroundImage(emptyImg, for: .normal)
        self.button4?.setBackgroundImage(emptyImg, for: .normal)
        self.button5?.setBackgroundImage(emptyImg, for: .normal)
    }

    func setFilledImagesForButtonsThrough(_ i: Int) {
        switch i {
        case 1:
            self.button1?.setBackgroundImage(filledImg, for: .normal)
        case 2:
            self.button1?.setBackgroundImage(filledImg, for: .normal)
            self.button2?.setBackgroundImage(filledImg, for: .normal)
        case 3:
            self.button1?.setBackgroundImage(filledImg, for: .normal)
            self.button2?.setBackgroundImage(filledImg, for: .normal)
            self.button3?.setBackgroundImage(filledImg, for: .normal)
        case 4:
            self.button1?.setBackgroundImage(filledImg, for: .normal)
            self.button2?.setBackgroundImage(filledImg, for: .normal)
            self.button3?.setBackgroundImage(filledImg, for: .normal)
            self.button4?.setBackgroundImage(filledImg, for: .normal)
        case 5:
            self.button1?.setBackgroundImage(filledImg, for: .normal)
            self.button2?.setBackgroundImage(filledImg, for: .normal)
            self.button3?.setBackgroundImage(filledImg, for: .normal)
            self.button4?.setBackgroundImage(filledImg, for: .normal)
            self.button5?.setBackgroundImage(filledImg, for: .normal)
        default: break
        }
    }

    func setDefaultImagesForRating() {
        self.emptyAllImages()
        setFilledImagesForButtonsThrough(self.currentRating)
    }

    @IBAction func ratingButtonPressed(_ button: UIButton) {
        switch button {
        case self.button1:
            self.currentRating = 1
        case self.button2:
            self.currentRating = 2
        case self.button3:
            self.currentRating = 3
        case self.button4:
            self.currentRating = 4
        case self.button5:
            self.currentRating = 5
        default: return
        }

        self.delegate?.ratingSelected(self.currentRating)
    }
}
