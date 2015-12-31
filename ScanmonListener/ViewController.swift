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
        timeFormatter.zeroFormattingBehavior = .DropLeading
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

    func titleChange(changeObject: AnyObject) {

        guard let newTitle = changeObject as? String else {
            DDLogError("View: Title change invalid type: \(changeObject)")
            return
        }

        DDLogInfo("View: title set: \(newTitle)")
        currentTitle.text = newTitle
    }

    func timeChange(changeObject: AnyObject) {

        guard let newTime = changeObject as? NSNumber else {
            DDLogError("View: Time change invalid type: \(changeObject)")
            return
        }

        if let strTime = timeFormatter.stringFromTimeInterval(newTime.doubleValue) {
            statusMessage.text = "Time: \(strTime)"
        }
    }

    func observeChange(change: [String : AnyObject]?, handler: (AnyObject) -> ()) -> String? {

        guard let changeDict = change else {
            return "status change invalid \(change)"
        }

        guard let kindNum = changeDict[NSKeyValueChangeKindKey] as? NSNumber else {
            return "KeyValueChange invalid value: \(changeDict[NSKeyValueChangeKindKey])"
        }

        guard let kind = NSKeyValueChange(rawValue: UInt(kindNum)) else {
            return "Invalid ChangeKind: \(kindNum)"
        }

        // Working code begins here ...
        if kind == NSKeyValueChange.Setting {
            if let newVal = changeDict[NSKeyValueChangeNewKey] {
                handler(newVal)
            } else {
                return "No new value found"
            }
        }

        return nil
    }

    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {

        guard let thisPath = keyPath else {
            DDLogError("View: Got nil keyPath for value change")
            return
        }

        guard object === playStream else {
            DDLogError("View: Unknown observed object \(object)")
            return
        }

        let result: String?

        switch thisPath {
        case "statusRaw":
            result = observeChange(change, handler: statusChange)
        case "title":
            result = observeChange(change, handler: titleChange)
        case "time":
            result = observeChange(change, handler: timeChange)
        default:
            result = "Got value change for unknown"
        }

        if result != nil {
            DDLogError("View: \(result!) for key change: \(thisPath)")
        }
    }
}

