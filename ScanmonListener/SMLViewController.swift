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

    var currentURL: NSURL!
    var playStream: SMLPlayStream!
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

        let defaults = NSUserDefaults.standardUserDefaults()
        self.currentURL = NSURL(string: defaults.objectForKey("streamURL") as! String)
        self.currentTitle.text = idleTitle
        self.statusLog.text = "Application started\n"
        self.streamURL.text = currentURL.absoluteString
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
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(SMLViewController.applicationNotification(_:)), name: UIApplicationDidEnterBackgroundNotification, object: UIApplication.sharedApplication())
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(SMLViewController.applicationNotification(_:)), name: UIApplicationDidBecomeActiveNotification, object: UIApplication.sharedApplication())
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

        var willStart = false

        if playStream == nil {
            playStream = SMLPlayStream(url: currentURL!)
            playStream.addObserver(self, forKeyPath: "statusRaw", options: .New, context: nil)
            playStream.addObserver(self, forKeyPath: "title", options: .New, context: nil)
            playStream.addObserver(self, forKeyPath: "time", options: .New, context: nil)
            playStream.addObserver(self, forKeyPath: "logentry", options: .New, context: nil)

            do {
                try avSession.setActive(true)

                playStream.play()
                willStart = true
            } catch {
                let emsg = "Can't start audio session: \(error)"
                DDLogError("\(emsg)")
                statusLog.appendLine(emsg)
            }
        } else {
            let emsg = "Play requested but already playing!"
            DDLogError("\(emsg)")
            statusLog.appendLine(emsg)
            buttonTitle = stopTitle
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
            buttonTitle = playTitle
            ps.pause()
        }
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
        DDLogVerbose("Entry")
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
            DDLogDebug("settingsButton touched")
        } else if sender === helpButton {
            DDLogDebug("helpButton touched")
        } else {
            DDLogError("View(\(#line)): \(#function): Unknown button: \(sender)")
        }
    }

    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        DDLogDebug("Entry")
        if streamURL.editing {
            streamURL.endEditing(true)
        }
        super.touchesBegan(touches, withEvent: event)
    }

    @IBAction func urlEditBegin(sender: UITextField) {
        DDLogDebug("Entry")
        playButton.enabled = false
    }

    @IBAction func urlEditingChanged(sender: UITextField) {
        DDLogDebug("Entry")
    }

    @IBAction func urlEditDidEndOnExit(sender: AnyObject) {
        DDLogDebug("Entry")
        sender.resignFirstResponder()
    }

    @IBAction func urlEditDidEnd(sender: UITextField) {
        DDLogDebug("Entry")

        playButton.enabled = true

        guard let newURLstring = sender.text else {
            DDLogError("nil value for streamURL!")
            return
        }

        guard newURLstring != currentURL.absoluteString else {
            DDLogInfo("No change in URL")
            return
        }

        guard let newURL = NSURL(string: newURLstring) else {
            let msg = "Invalid URL entered: \(newURLstring)"
            statusLog.appendLine(msg)
            DDLogWarn(msg)
            sender.text = currentURL.absoluteString
            return
        }

        playStream?.stop("URL changed")
        currentURL = newURL
        DDLogDebug("New URL: \(newURLstring)")
        statusLog.appendLine("New URL: \(newURLstring)")
        NSUserDefaults.standardUserDefaults().setValue(newURLstring, forKey: "streamURL")
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
        var newSet = [String]()
        let dest = segue.sourceViewController as! SettingsViewController
        let defaults = NSUserDefaults.standardUserDefaults()

        if dest.autoRetry != defaults.boolForKey("autoRetry") {
            defaults.setBool(dest.autoRetry, forKey: "autoRetry")
            newSet.append("Auto Retry: \(dest.autoRetry)")
        }

        if dest.backgroundAudio != defaults.boolForKey("backgroundAudio") {
        defaults.setBool(dest.backgroundAudio, forKey: "backgroundAudio")
            newSet.append("Background Audio: \(dest.backgroundAudio)")
        }

        if dest.disableLock != defaults.boolForKey("disableLock") {
        defaults.setBool(dest.disableLock, forKey: "disableLock")
            newSet.append("Disable Lock: \(dest.disableLock)")
        }

        DDLogInfo("New settings: \(newSet.joinWithSeparator(", "))")
    }

    @IBAction func settingsReturnedCancel(segue: UIStoryboardSegue) {
        DDLogInfo("Settings cancelled")
    }
    
    func statusChange(changeObject: AnyObject?) -> String? {
        DDLogDebug("Entry")

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
        case .Paused:
            msg = "Paused"
        }

        statusMessage.text = msg

        return nil
    }

    func logEntry(changeObject: AnyObject?) -> String? {
        DDLogDebug("Entry")

        guard let newLog = changeObject as? String else {
            return "Log entry invalid type: '\(changeObject!)'"
        }

        DDLogInfo("log entry: \(newLog)")

        statusLog.appendLine(newLog)

        return nil
    }

    func titleChange(changeObject: AnyObject?) -> String? {
        DDLogDebug("Entry")

        var newTitle: String

        if let nt = changeObject as? String  {
            newTitle = nt
        } else if changeObject! is NSNull {
            newTitle = idleTitle
        } else {
            return("Title change invalid type: '\(changeObject)'")
        }
        
        DDLogInfo("title change: \(newTitle)")

        currentTitle.text = newTitle

        return nil
    }

    func timeChange(changeObject: AnyObject?) -> String? {
        //        DDLogDebug("Entry")  // Too chatty!

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

        // DDLogDebug("keyPath changed: \(thisPath)")

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
}