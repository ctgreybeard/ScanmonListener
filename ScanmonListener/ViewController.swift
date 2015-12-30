//
//  ViewController.swift
//  ScanmonListener
//
//  Created by William Waggoner on 12/28/15.
//  Copyright © 2015 William C Waggoner. All rights reserved.
//

import UIKit

import CocoaLumberjack

class ViewController: UIViewController {


    @IBOutlet weak var statusMessage: UILabel!
    @IBOutlet weak var statusLog: SMLLogScrollView!
    @IBOutlet weak var streamURL: UITextField!
    @IBOutlet weak var currentTitle: UILabel!
    @IBOutlet weak var playButton: UIButton!

    var currentURL = "http://www.greybeard.org/scanner"
    var playStream: SMLPlayStream?
    var activity: NSObjectProtocol?
    var buttonTitle = "Ready" {
        didSet {
            playButton.setTitle(buttonTitle, forState: [.Normal])
            DDLogDebug("View: button set: '\(buttonTitle)'")
        }
    }

    let playTitle = "Play"
    let stopTitle = "Stop"
    let startTitle = "Starting"

    // Internal variables
    let timeFormatter = NSDateComponentsFormatter()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        DDLogInfo("View Loaded")
        self.currentTitle.text = "Fire/EMS"
        self.statusLog.text = "Application started"
        self.streamURL.text = currentURL
        playButton.titleLabel?.adjustsFontSizeToFitWidth = true
        playButton.titleLabel?.minimumScaleFactor = 0.5
        if let myView = view as? UIScrollView {
            DDLogDebug("View: scrolling enabled: \(myView.scrollEnabled)")
        }

        // Initialize the time formatter
        timeFormatter.allowedUnits = [.Hour, .Minute, .Second]
        timeFormatter.unitsStyle = .Abbreviated
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        DDLogWarn("Memory Warning!")
    }

    override func viewDidAppear(animated: Bool) {
        DDLogDebug("View: viewDidAppear")
    }

    override func viewDidDisappear(animated: Bool) {
        DDLogDebug("View: viewDidDisappear")
    }

    override func viewWillAppear(animated: Bool) {
        DDLogDebug("View: viewWillAppear")
    }

    override func viewWillDisappear(animated: Bool) {
        DDLogDebug("View: viewWillDisappear")
    }

    func doPlay() -> Bool {
        var willStart = false

        if playStream == nil {
            playStream = SMLPlayStream()
            playStream?.addObserver(self, forKeyPath: "statusRaw", options: .New, context: nil)
            playStream?.addObserver(self, forKeyPath: "title", options: .New, context: nil)
            playStream?.addObserver(self, forKeyPath: "time", options: .New, context: nil)

            willStart = playStream?.play(currentURL) ?? false

            if willStart {
                activity = NSProcessInfo.processInfo().beginActivityWithOptions([.UserInitiated, .IdleDisplaySleepDisabled, .IdleSystemSleepDisabled], reason: "Play started")
                buttonTitle = startTitle
            }
        } else {
            DDLogError("View: Play requested but already playing!")
            buttonTitle = stopTitle
        }

        return willStart
    }

    func didPlay() {
        DDLogDebug("View: didPlay")
        buttonTitle = stopTitle
    }

    func didFail() {
        DDLogDebug("View: didFail")
        didStop()
    }

    func doStop() {
        DDLogDebug("View: doStop")
        playStream?.stop()
    }

    func didStop() {
        DDLogDebug("View: didStop")
        buttonTitle = playTitle

        if let ps = playStream {
            ps.removeObserver(self, forKeyPath: "statusRaw")
            ps.removeObserver(self, forKeyPath: "title")
            ps.removeObserver(self, forKeyPath: "time")
            playStream = nil
        }

        if (activity != nil) {
            NSProcessInfo.processInfo().endActivity(activity!)
            activity = nil
        }
    }

    @IBAction func buttonTouch(sender: UIButton) {
        DDLogDebug("Button Touched!")
        if let thisTitle = sender.currentTitle {
            if thisTitle == "Play" {
                if doPlay() {
                    DDLogDebug("View: Play requested")
                    self.statusLog.appendLine("Playing \(currentURL)")
                } else {
                    self.statusLog.appendLine("Play failed")
                    DDLogError("View: Play request failed")
                }
            } else {
                DDLogDebug("View: Stop requested")
                doStop()
            }
        } else {
            DDLogError("No button tile!")
            sender.setTitle("HUH!?", forState: UIControlState.Normal)
        }
    }
    @IBAction func urlUpdated(sender: UITextField) {
        DDLogDebug("URL Updated")
        if let newURL = sender.text {
            self.currentURL = sender.text!
            DDLogDebug("New URL: \(newURL)")
            self.statusLog.appendLine("New URL: \(newURL)")
        } else {
            DDLogError("nil value for streamURL!")
        }
    }

    @IBAction func urlChanged(sender: UITextField) {
        DDLogDebug("URL Changed")
    }

    @IBAction func urlAction(sender: UITextField) {
        DDLogDebug("URL Action")
        sender.endEditing(false)
    }

    func statusChange(changeObject: AnyObject) {
        var msg = "??"
        if let newStatus = changeObject as? String {
            DDLogInfo("View: Status set: \(newStatus)")
            if let changeTo = PlayStatus(rawValue: newStatus) {
                switch changeTo {
                case .Playing:
                    msg = "Playing"
                    didPlay()
                case .Ready:
                    msg = "Ready"
                case .Starting:
                    msg = "Starting"
                case .Stopped:
                    msg = "Stopped"
                    didStop()
                case .Stopping:
                    msg = "Stopping"
                case .Failed:
                    msg = "Failed"
                    didFail()
                }
                DDLogInfo("View: Stream status change: \(msg)")
                statusMessage.text = msg
            }
        } else {
            DDLogError("View: Status change invalid type: \(changeObject)")
        }
    }

    func observeTitle(ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        if let changeDict = change {
            if let kindNum = changeDict[NSKeyValueChangeKindKey] as? NSNumber {
                if let kind = NSKeyValueChange(rawValue: UInt(kindNum)) {
                    if let newVal = changeDict[NSKeyValueChangeNewKey] {
                        let newTitle = newVal as! String
                        if kind == NSKeyValueChange.Setting {
                            DDLogInfo("View: title set: \(newTitle)")
                            currentTitle.text = newTitle
                        }
                    }
                } else {
                    DDLogError("View: KeyValueChange invalid value: \(kindNum)")
                }
            } else {
                DDLogError("View: status change invalid \(changeDict[NSKeyValueChangeKindKey])")
            }
        }
    }

    func observeTime(ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        if let changeDict = change {
            if let kindNum = changeDict[NSKeyValueChangeKindKey] as? NSNumber {
                if let kind = NSKeyValueChange(rawValue: UInt(kindNum)) {
                    if let newVal = changeDict[NSKeyValueChangeNewKey] {
                        let newTime = newVal as! NSNumber
                        if kind == NSKeyValueChange.Setting {
                            // DDLogDebug("View: time set: \(newTime)")
                            if let strTime = timeFormatter.stringFromTimeInterval(newTime.doubleValue) {
                                statusMessage.text = "Time: \(strTime)"
                            }
                        }
                    }
                } else {
                    DDLogError("View: KeyValueChange invalid value: \(kindNum)")
                }
            } else {
                DDLogError("View: status change invalid \(changeDict[NSKeyValueChangeKindKey])")
            }
        }
    }

    func observeChange(ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>, handler: (AnyObject) -> ()) {
        if let changeDict = change {
            if let kindNum = changeDict[NSKeyValueChangeKindKey] as? NSNumber {
                if let kind = NSKeyValueChange(rawValue: UInt(kindNum)) {
                    if kind == NSKeyValueChange.Setting {
                        if let newVal = changeDict[NSKeyValueChangeNewKey] {
                            // DDLogDebug("View: time set: \(newTime)")
                            handler(newVal)
                        }
                    }
                } else {
                    DDLogError("View: KeyValueChange invalid value: \(kindNum)")
                }
            } else {
                DDLogError("View: status change invalid \(changeDict[NSKeyValueChangeKindKey])")
            }
        }
    }

    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        if let thisPath = keyPath {
            // DDLogDebug("View: Observed value change for \(thisPath)")
            if object === playStream {
                switch thisPath {
                case "statusRaw":
                    observeChange(ofObject: object, change: change, context: context, handler: statusChange)
                case "title":
                    observeTitle(ofObject: object, change: change, context: context)
                case "time":
                    observeTime(ofObject: object, change: change, context: context)
                default:
                    DDLogError("View: Got value change for unknown: \(thisPath)")
                }
            } else {
                DDLogError("View: Unknown observed object \(object)")
            }
        } else {
            DDLogError("View: Got nil key for value change")
        }
    }
}

