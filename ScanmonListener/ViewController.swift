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

    var currentURL = "http://scanmon.greybeard.org:8000/scanner.mp3"
    var playStream: SMLPlayStream?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        DDLogInfo("View Loaded")
        self.currentTitle.text = "Nothing playing..."
        self.statusLog.text = "Application started"
        self.streamURL.text = currentURL
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        DDLogWarn("Memory Warning!")
    }

    func doPlay() -> Bool {

        playStream = SMLPlayStream()
        playStream?.addObserver(self, forKeyPath: "statusRaw", options: .New, context: nil)
        playStream?.addObserver(self, forKeyPath: "title", options: .New, context: nil)

        return playStream?.play(currentURL) ?? false
    }

    func doStop() {
        playStream?.stop()
        playStream?.removeObserver(self, forKeyPath: "statusRaw")
        playStream?.removeObserver(self, forKeyPath: "title")
        playStream = nil
    }

    @IBAction func buttonTouch(sender: UIButton) {
        DDLogDebug("Button Touched!")
        if let thisTitle = sender.titleLabel?.text {
            if thisTitle == "Play" {
                if doPlay() {
                    DDLogDebug("Button is: '\(thisTitle)', Setting to Stop")
                    sender.setTitle("Stop", forState: UIControlState.Normal)
                    self.currentTitle.text = "...playing..."
                    self.statusLog.appendLine("Playing \(currentURL)")
                } else {
                    self.statusLog.appendLine("Play failed")
                    DDLogError("Play failed")
                }
            } else {
                DDLogDebug("Button is: '\(thisTitle)', Setting to Play")
                sender.setTitle("Play", forState: UIControlState.Normal)
                doStop()
                self.currentTitle.text = "Nothing playing..."
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

    func statusChange(newStatus: PlayStatus) {
        var msg = "??"
        switch newStatus {
        case .Playing:
            msg = "Playing"
        case .Ready:
            msg = "Ready"
        case .Starting:
            msg = "Starting"
        case .Stopped:
            msg = "Stopped"
        case .Stopping:
            msg = "Stopping"
        }
        DDLogInfo("Stream status change: \(msg)")
        statusMessage.text = msg
    }

    func observeStatus(ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        if let changeDict = change {
            if let kindNum = changeDict[NSKeyValueChangeKindKey] as? NSNumber {
                if let kind = NSKeyValueChange(rawValue: UInt(kindNum)) {
                    if let newVal = changeDict[NSKeyValueChangeNewKey] {
                        let newStatus = newVal as! String
                        if kind == NSKeyValueChange.Setting {
                            DDLogInfo("View: Status set: \(newStatus)")
                            if let changeTo = PlayStatus(rawValue: newStatus) {
                                statusChange(changeTo)
                            } else {
                                DDLogError("View: status change invalid value: \(newStatus)")
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

    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        if let thisPath = keyPath {
            DDLogDebug("View: Observed value change for \(thisPath)")
            switch thisPath {
            case "statusRaw":
                if object === playStream {
                    observeStatus(ofObject: object, change: change, context: context)
                } else {
                    DDLogError("View: Unknown observed object \(object)")
                }
            case "title":
                if object === playStream {
                    observeTitle(ofObject: object, change: change, context: context)
                } else {
                    DDLogError("View: Unknown observed object \(object)")
                }
            default:
                DDLogError("View: Got value change for unknown: \(thisPath)")
            }
        } else {
            DDLogError("View: Got nil key for value change")
        }
    }
}

