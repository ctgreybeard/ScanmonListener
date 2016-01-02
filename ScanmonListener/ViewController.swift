//
//  ViewController.swift
//  ScanmonListener
//
//  Created by William Waggoner on 12/28/15.
//  Copyright © 2015 William C Waggoner. All rights reserved.
//

import UIKit
import MediaPlayer

import CocoaLumberjack
import AVFoundation

class SMLViewController: UIViewController {


    @IBOutlet weak var mpVolumeParent: UIView!
    @IBOutlet weak var statusMessage: UILabel!
    @IBOutlet weak var statusLog: SMLLogScrollView!
    @IBOutlet weak var streamURL: UITextField!
    @IBOutlet weak var currentTitle: UILabel!
    @IBOutlet weak var playButton: UIButton!

    var currentURL = "http://www.greybeard.org/scanner"
    var playStream: SMLPlayStream!
    var activity: NSObjectProtocol?
    dynamic var buttonTitle = "Ready" {
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
    var avSession: AVAudioSession!
    let app = UIApplication.sharedApplication().delegate as! AppDelegate
    
    override func viewDidLoad() {
        super.viewDidLoad()

        DDLogInfo("View Loaded")
        self.currentTitle.text = "Fire/EMS"
        self.statusLog.text = "Application started"
        self.streamURL.text = currentURL
        playButton.titleLabel?.adjustsFontSizeToFitWidth = true
        playButton.titleLabel?.minimumScaleFactor = 0.5

        //mpVolumeParent.backgroundColor = UIColor.clearColor()
        let vbounds = mpVolumeParent.bounds.insetBy(dx: 8.0, dy: 8.0)
        mpVolumeParent.addSubview(MPVolumeView(frame: vbounds))
        weak var volView: MPVolumeView! = mpVolumeParent.subviews[0] as? MPVolumeView
        volView?.showsRouteButton = true

        // Initialize the time formatter
        timeFormatter.allowedUnits = [.Hour, .Minute, .Second]
        timeFormatter.unitsStyle = .Abbreviated
        timeFormatter.zeroFormattingBehavior = .DropLeading

        avSession = app.avSession
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
            playStream.addObserver(self, forKeyPath: "statusRaw", options: .New, context: nil)
            playStream.addObserver(self, forKeyPath: "title", options: .New, context: nil)
            playStream.addObserver(self, forKeyPath: "time", options: .New, context: nil)
            playStream.addObserver(self, forKeyPath: "logentry", options: .New, context: nil)

            do {
                try avSession.setActive(true)

                willStart = playStream.play(currentURL)

                if willStart {
                    activity = NSProcessInfo.processInfo().beginActivityWithOptions([.UserInitiated, .IdleDisplaySleepDisabled], reason: "Play started")
                    buttonTitle = startTitle
                }
            } catch {
                let emsg = "Can't start audio session: \(error)"
                DDLogError("View: \(emsg)")
                statusLog.appendLine(emsg)
            }
        } else {
            let emsg = "Play requested but already playing!"
            DDLogError("View: \(emsg)")
            statusLog.appendLine(emsg)
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
        playStream?.stop("Stop requested")
    }

    func didStop() {
        DDLogDebug("View: didStop")
        buttonTitle = playTitle

        if let ps = playStream {
            ps.removeObserver(self, forKeyPath: "statusRaw")
            ps.removeObserver(self, forKeyPath: "title")
            ps.removeObserver(self, forKeyPath: "time")
            ps.removeObserver(self, forKeyPath: "logentry")
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

    func statusChange(changeObject: AnyObject?) -> String? {

        guard let newStatus = changeObject as? String else {
            return "Status change invalid type: '\(changeObject!)'"
        }

        guard let changeTo = PlayStatus(rawValue: newStatus) else {
            return "Status change invalid value '\(newStatus)'"
        }

        DDLogInfo("View: Status set: \(changeTo)")

        let msg: String

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

        statusMessage.text = msg

        return nil
    }

    func logEntry(changeObject: AnyObject?) -> String? {

        guard let newLog = changeObject as? String else {
            return "Log entry invalid type: '\(changeObject!)'"
        }

        DDLogInfo("View: log entry: \(newLog)")

        statusLog.appendLine(newLog)

        return nil
    }
    
    func titleChange(changeObject: AnyObject?) -> String? {

        guard let newTitle = changeObject as? String else {
            return "Title change invalid type: '\(changeObject!)'"
        }

        DDLogInfo("View: title set: \(newTitle)")

        currentTitle.text = newTitle

        return nil
    }

    func timeChange(changeObject: AnyObject?) -> String? {

        guard let newTime = changeObject as? NSNumber else {
            return "Time change invalid type: '\(changeObject!)'"
        }

        guard let strTime = timeFormatter.stringFromTimeInterval(newTime.doubleValue) else {
            return "Time change invalid time value '\(newTime)'"
        }

        statusMessage.text = "Time: \(strTime)"

        return nil
    }

    func observeChange(change: [String : AnyObject]?, handler: (AnyObject?) -> String?) -> String? {

        guard let changeDict = change else {
            return "KeyValueChange change invalid '\(change!)'"
        }

        guard let kindNum = changeDict[NSKeyValueChangeKindKey] as? NSNumber else {
            return "KeyValueChange value invalid: '\(changeDict[NSKeyValueChangeKindKey]!)'"
        }

        guard let kind = NSKeyValueChange(rawValue: UInt(kindNum)) else {
            return "KeyValueChange change kind invalid: '\(kindNum)'"
        }

        guard kind == NSKeyValueChange.Setting else {
            return "KeyValueChange unexpected change kind: '\(kind)'"
        }

        // Working code begins here ...
        return handler(changeDict[NSKeyValueChangeNewKey])
    }

    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {

        guard let thisPath = keyPath else {
            DDLogError("View: Got nil keyPath for value change")
            return
        }

        guard object === playStream else {
            DDLogError("View: Unknown observed object '\(object!)'")
            return
        }

        // DDLogDebug("View: keyPath changed: \(thisPath)")

        let result: String?

        switch thisPath {
        case "statusRaw":
            result = observeChange(change, handler: statusChange)

        case "title":
            result = observeChange(change, handler: titleChange)

        case "time":
            result = observeChange(change, handler: timeChange)

        case "logentry":
            result = observeChange(change, handler: logEntry)

        default:
            result = "Got value change for unknown"
        }

        if result != nil {
            DDLogError("View: \(result!) for key change: \(thisPath)")
        }
    }
}