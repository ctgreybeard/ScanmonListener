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
    @IBOutlet weak var settingsButton: UIButton!
    @IBOutlet weak var helpButton: UIButton!

    var currentURL = "http://www.greybeard.org/scanner"
    var playStream: SMLPlayStream?
    dynamic var buttonTitle = "Ready" {
        didSet {
        playButton.setTitle(buttonTitle, forState: [.Normal])
        DDLogDebug("button set: '\(buttonTitle)'")
        }
    }

    let playTitle = "Play"
    let stopTitle = "Stop"
    let startTitle = "Starting"
    let idleTitle = "Fire/EMS"

    // Internal variables
    let timeFormatter = NSDateComponentsFormatter()
    var avSession: AVAudioSession!
    let app = UIApplication.sharedApplication().delegate as! AppDelegate
    var mpVV: MPVolumeView!

    override func viewDidLoad() {
        super.viewDidLoad()

        DDLogDebug("Entry")

        self.currentTitle.text = idleTitle
        self.statusLog.text = "Application started\n"
        self.streamURL.text = currentURL
        playButton.titleLabel?.adjustsFontSizeToFitWidth = true
        playButton.titleLabel?.minimumScaleFactor = 0.5

        let mpVVbounds = mpVolumeParent.bounds.insetBy(dx: 4.0, dy: 10.0)
        mpVV = MPVolumeView(frame: mpVVbounds)
        mpVV.translatesAutoresizingMaskIntoConstraints = false

        mpVolumeParent.addSubview(mpVV)

        // Initialize the time formatter
        timeFormatter.allowedUnits = [.Hour, .Minute, .Second]
        timeFormatter.unitsStyle = .Abbreviated
        timeFormatter.zeroFormattingBehavior = .DropLeading

        avSession = app.avSession

        // Register for application notifications
        let defs = NSNotificationCenter.defaultCenter()
        defs.addObserver(self, selector: "applicationNotification:", name: UIApplicationDidEnterBackgroundNotification, object: UIApplication.sharedApplication())
        defs.addObserver(self, selector: "applicationNotification:", name: UIApplicationDidBecomeActiveNotification, object: UIApplication.sharedApplication())
        defs.addObserver(self, selector: "defaultsChanged:", name: NSUserDefaultsDidChangeNotification, object: app.preferences)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        DDLogWarn("Entry")
    }

    override func viewDidAppear(animated: Bool) {
        DDLogDebug("Entry")
    }

    override func viewDidDisappear(animated: Bool) {
        DDLogDebug("Entry")
    }

    override func viewWillAppear(animated: Bool) {
        DDLogDebug("Entry")
    }

    override func viewWillDisappear(animated: Bool) {
        DDLogDebug("Entry")
    }

    func doPlay() -> Bool {
        DDLogDebug("Entry")

        let willStart: Bool

        if let ps = playStream  {
            if ps.status == .Paused {
                willStart = true

            } else {
                let emsg = "Play requested but already playing!"
                DDLogError(emsg)
                statusLog.appendLine(emsg)
                buttonTitle = stopTitle
                willStart = false
            }
            ps.play()

        } else {

            playStream = SMLPlayStream()
            playStream!.addObserver(self, forKeyPath: "statusRaw", options: .New, context: nil)
            playStream!.addObserver(self, forKeyPath: "title", options: .New, context: nil)
            playStream!.addObserver(self, forKeyPath: "time", options: .New, context: nil)
            playStream!.addObserver(self, forKeyPath: "logentry", options: .New, context: nil)

            do {
                try avSession.setActive(true)

                playStream!.play(currentURL)
                willStart = true
            } catch {
                willStart = false
                let emsg = "Can't start audio session: \(error)"
                DDLogError("\(emsg)")
                statusLog.appendLine(emsg)
            }
        }
        
        return willStart
        
    }

    func didPlay() {
        DDLogDebug("Entry")

        buttonTitle = stopTitle

        // Begin our activity
        if NSUserDefaults.standardUserDefaults().boolForKey("disableLock") {
            UIApplication.sharedApplication().idleTimerDisabled = true
        }

        DDLogInfo("Playback started")
    }

    func didFail() {
        DDLogDebug("Entry")
        didStop()
    }

    func doStop() {
        DDLogDebug("Entry")
        playStream?.stop("Stop requested")
    }

    func doPause() {
        DDLogDebug("Entry")

        if let ps = playStream {
            ps.pause()
        }
    }

    func didPause() {
        buttonTitle = playTitle
    }

    func doResume() {
        DDLogDebug("Entry")

        if let ps = playStream {
            buttonTitle = stopTitle
            ps.resume()
        }
    }

    func didStop() {
        DDLogDebug("Entry")
        buttonTitle = playTitle

        if let ps = playStream {
            ps.removeObserver(self, forKeyPath: "statusRaw")
            ps.removeObserver(self, forKeyPath: "title")
            ps.removeObserver(self, forKeyPath: "time")
            ps.removeObserver(self, forKeyPath: "logentry")
            playStream = nil
        }

        UIApplication.sharedApplication().idleTimerDisabled = false

    }

    @IBAction func buttonTouch(sender: UIButton) {
        DDLogDebug("Entry")
        if sender === playButton {
            if let thisTitle = sender.currentTitle {
                if thisTitle == "Play" {
                    if doPlay() {
                        DDLogDebug("Play requested")
                        self.statusLog.appendLine("Playing \(currentURL)")
                    } else {
                        self.statusLog.appendLine("Play failed")
                        DDLogError("Play request failed")
                    }
                } else {
                    DDLogDebug("Stop requested")
                    doStop()
                }
            } else {
                DDLogError("No button tile!")
                sender.setTitle("HUH!?", forState: UIControlState.Normal)
            }
        } else if sender === settingsButton {

        } else if sender === helpButton {

        } else {
            DDLogError("View(\(__LINE__)): \(__FUNCTION__): Unknown button: \(sender)")
        }
    }

    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        DDLogDebug("Entry")
        streamURL.endEditing(true)
        super.touchesBegan(touches, withEvent: event)
    }

    @IBAction func urlEditEnd(sender: AnyObject) {
        DDLogDebug("Entry")
        sender.resignFirstResponder()
    }

    @IBAction func urlUpdated(sender: UITextField) {
        DDLogDebug("Entry")
        if let newURL = sender.text {
            self.currentURL = sender.text!
            DDLogDebug("New URL: \(newURL)")
            self.statusLog.appendLine("New URL: \(newURL)")
        } else {
            DDLogError("nil value for streamURL!")
        }
    }

    @IBAction func urlChanged(sender: UITextField) {
        DDLogDebug("Entry")
    }

    @IBAction func urlAction(sender: UITextField) {
        DDLogDebug("Entry")
        sender.endEditing(false)
    }

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        DDLogDebug("Entry")
        if sender === settingsButton {
            let dest = segue.destinationViewController as! SettingsViewController

            let defaults = NSUserDefaults.standardUserDefaults()
            dest.autoRetry = defaults.boolForKey("autoRetry")

            dest.backgroundAudio = defaults.boolForKey("backgroundAudio")

            dest.disableLock = defaults.boolForKey("disableLock")

        }
    }

    @IBAction func aboutReturned(segue: UIStoryboardSegue) {
        // Do nothing
        DDLogInfo("About returned")
    }

    @IBAction func settingsReturnedOK(segue: UIStoryboardSegue) {
        DDLogInfo("Settings OK")
        let dest = segue.sourceViewController as! SettingsViewController
        let defaults = NSUserDefaults.standardUserDefaults()
        defaults.setBool(dest.autoRetry, forKey: "autoRetry")
        defaults.setBool(dest.backgroundAudio, forKey: "backgroundAudio")
        defaults.setBool(dest.disableLock, forKey: "disableLock")
        DDLogInfo("New settings: autoRetry: \(dest.autoRetry), backgroundAudio: \(dest.backgroundAudio), disableLock: \(dest.disableLock)")
    }

    @IBAction func settingsReturnedCancel(segue: UIStoryboardSegue) {
        DDLogInfo("Settings cancelled")
    }

    func observeChange(change: [String : AnyObject]?, handler: (AnyObject?) -> String?) -> String? {
        //        DDLogDebug("Entry")  // Too chatty!

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
        //        DDLogDebug("Entry")  // Too chatty!

        guard let thisPath = keyPath else {
            DDLogError("Got nil keyPath for value change")
            return
        }

        guard object === playStream else {
            DDLogError("Unknown observed object '\(object!)'")
            return
        }

        let result: String?

        switch thisPath {
        case "statusRaw":
            result = observeChange(change) {(changeObject: AnyObject?) -> String? in
                DDLogDebug("statusRaw")

                guard let newStatus = changeObject as? String else {
                    return "Status change invalid type: '\(changeObject!)'"
                }

                guard let changeTo = PlayStatus(rawValue: newStatus) else {
                    return "Status change invalid value '\(newStatus)'"
                }

                DDLogInfo("Status set: \(changeTo)")

                let msg: String

                switch changeTo {
                case .Playing:
                    msg = "Playing"
                    self.didPlay()

                case .Ready:
                    msg = "Ready"

                case .Starting:
                    msg = "Starting"

                case .Stopped:
                    msg = "Stopped"
                    self.didStop()

                case .Stopping:
                    msg = "Stopping"

                case .Failed:
                    msg = "Failed"
                    self.didFail()

                case .Paused:
                    msg = "Paused"

                case .Retrying:
                    msg = "Retrying"
                }

                self.statusMessage.text = msg

                return nil
            }


        case "title":
            result = observeChange(change) {(changeObject: AnyObject?) -> String? in
                DDLogDebug("title")

                var newTitle: String

                if let nt = changeObject as? String  {
                    newTitle = nt
                } else if changeObject! is NSNull {
                    newTitle = self.idleTitle
                } else {
                    return("Title change invalid type: '\(changeObject)'")
                }

                DDLogInfo("title set: \(newTitle)")

                self.currentTitle.text = newTitle

                return nil
            }

        case "time":
            result = observeChange(change) {(changeObject: AnyObject?) -> String? in
                DDLogVerbose("time")
                guard let newTime = changeObject as? NSNumber else {
                    return "Time change invalid type: '\(changeObject!)'"
                }

                guard let strTime = self.timeFormatter.stringFromTimeInterval(newTime.doubleValue) else {
                    return "Time change invalid time value '\(newTime)'"
                }

                self.statusMessage.text = "Time: \(strTime)"

                return nil
            }

        case "logentry":
            result = observeChange(change) {(changeObject: AnyObject?) -> String? in
                DDLogDebug("logentry")

                guard let newLog = changeObject as? String else {
                    return "Log entry invalid type: '\(changeObject!)'"
                }

                DDLogInfo("log entry: \(newLog)")

                self.statusLog.appendLine(newLog)

                return nil
            }

        default:
            result = "Got value change for unknown"
        }
        
        if result != nil {
            DDLogError("\(result!) for key change: \(thisPath)")
        }
    }
    
    func appDidBackground(notice: NSNotification) {
        DDLogDebug("Entry")
        
        if !NSUserDefaults.standardUserDefaults().boolForKey("backgroundAudio") {
            doPause()
        }
    }
    
    func appIsActive(notice: NSNotification) {
        DDLogDebug("Entry")
        
        if !NSUserDefaults.standardUserDefaults().boolForKey("backgroundAudio") {
            doResume()
        }
        
    }
    
    dynamic func applicationNotification(notice: NSNotification) {
        DDLogDebug("Entry")
        
        switch notice.name {
            
        case UIApplicationDidBecomeActiveNotification:
            appIsActive(notice)
            
        case UIApplicationDidEnterBackgroundNotification:
            appDidBackground(notice)
            
        default:
            DDLogDebug("Unhandled Notification: '\(notice.name)'")
            
        }
    }

    // User defaults notification
    dynamic func defaultsChanged(notice: NSNotification) {
        DDLogDebug("Entry: \(notice.name)")
        let defs = NSUserDefaults.standardUserDefaults()
        let idleT = defs.boolForKey("disableLock")
        if idleT {
            // Assume it was turned ON
            if playStream != nil && playStream!.playing {
                UIApplication.sharedApplication().idleTimerDisabled = true  // Only turn it on if we are playing
            }
        } else {
            // Assume it was turned OFF
            UIApplication.sharedApplication().idleTimerDisabled = false // Doesn't matter if we turn it off when it's off
        }
    }
}