//
//  SMLPlayStream.swift
//  ScanmonListener
//
//  Created by William Waggoner on 12/28/15.
//  Copyright © 2015 William C Waggoner. All rights reserved.
//

import UIKit

import AVFoundation

import CocoaLumberjack

enum PlayStatus: String {
    case Ready = "ready"
    case Starting = "starting"
    case Playing = "playing"
    case Stopping = "stopping"
    case Stopped = "stopped"
    case Failed = "Failed"
}

class SMLPlayStream: NSObject {

    var _player: AVPlayer?
    var _url: NSURL?
    
    dynamic private(set) var statusRaw: String?

    var status: PlayStatus = .Ready {
        didSet {
            DDLogDebug("Player: status set")
            statusRaw = status.rawValue
        }
    }

    dynamic var title: String?
    dynamic var time: NSNumber?

    // Private instance variables
    private var timeObserver: AnyObject?

    dynamic func audioNotification(note: NSNotification) {
        DDLogDebug("Player: Audio Notification: \(note)")
    }

    func play(url: String) -> Bool {
        var ok: Bool = false

        DDLogInfo("Player starting: \(url)")
        if playing {
            stop()
        }

        if let newURL = NSURL(string: url) {
            self.url = newURL
            DDLogInfo("Attempting to play: \(newURL)")

            let newPlayer = AVPlayer(URL: newURL)
            _player = newPlayer

            // Set play parameters
            newPlayer.actionAtItemEnd = .Pause

            // Set observers
            newPlayer.addObserver(self, forKeyPath: "status", options: .New, context: nil)
            newPlayer.addObserver(self, forKeyPath: "currentItem.timedMetadata", options: .New, context: nil)
            timeObserver = newPlayer.addPeriodicTimeObserverForInterval(CMTime(seconds: 1.0, preferredTimescale: 10), queue: nil, usingBlock: {(time: CMTime) in
                    self.time = time.seconds
                })

            status = .Starting

            let aSess = AVAudioSession.sharedInstance()
            do {
                try aSess.setActive(true)
            }
            catch {
                DDLogError("Audio session failed: \(error)")
            }

            // Set up notifications
            NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("audioNotification:"), name: nil, object: aSess)

            ok = true
        } else {
            DDLogError("Create URL failed")
        }

        return ok
    }

    func stop() {
        DDLogInfo("Player stopping")
        _player?.pause()
        _player?.removeObserver(self, forKeyPath: "status")
        _player?.removeObserver(self, forKeyPath: "currentItem.timedMetadata")
        _player?.removeTimeObserver(timeObserver!)
        timeObserver = nil

        // Remove notifications
        NSNotificationCenter.defaultCenter().removeObserver(self)

        _player = nil
        status = .Stopped
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        }
        catch {
            DDLogError("Audio session failed: \(error)")
        }

}

    var playing: Bool {
        get {
            return status == .Playing
        }
    }

    var url: NSURL? {
        get {
            return _url
        }

        set(newURL) {
        }
    }

    func statusChange(status: AVPlayerStatus) {
        DDLogDebug("Player: statusChange")
        switch status {
        case .Unknown:
            DDLogInfo("Player: status change to Unknown")
        case .ReadyToPlay:
            DDLogInfo("Player: status change to ReadyToPlay")
            _player?.play()
            self.status = .Playing
        case .Failed:
            DDLogInfo("Player: status change to Failed: \(_player?.error)")
            self.status = .Failed
        }
    }

    func metadataChange(data: [AVMetadataItem]) {
        DDLogDebug("Player: metadataChange")
        // Loop through the metadata looking for the title
        for md in AVMetadataItem.metadataItemsFromArray(data, withKey: "title", keySpace: "comn") {
            if let realTitle = md.stringValue {
                title = realTitle
                DDLogInfo("Player: Set title: '\(realTitle)'")
            } else {
                DDLogWarn("Player: Unexpected value for title: '\(md.value)', type=\(md.dataType)")
            }
        }
    }

    func observeStatus(ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        DDLogDebug("Player: observeStatus")
        if let changeDict = change {
            if let kindNum = changeDict[NSKeyValueChangeKindKey] as? NSNumber {
                if let kind = NSKeyValueChange(rawValue: UInt(kindNum)) {
                    if let newVal = changeDict[NSKeyValueChangeNewKey] {
                        let newStatus = newVal as! Int
                        if kind == NSKeyValueChange.Setting {
                            DDLogInfo("Player: Status set: \(newStatus)")
                            if let changeTo = AVPlayerStatus(rawValue: newStatus) {
                                statusChange(changeTo)
                            }
                        }
                    }
                }
            } else {
                DDLogError("Player: status change invalid \(changeDict[NSKeyValueChangeKindKey])")
            }
        } else {
            DDLogWarn("Player: status: no change dictionary?")
        }
    }

    func observeMetadata(ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        DDLogDebug("Player: observeMetadata")
        if let changeDict = change {
            if let kindNum = changeDict[NSKeyValueChangeKindKey] as? NSNumber {
                if let kind = NSKeyValueChange(rawValue: UInt(kindNum)) {
                    DDLogDebug("Player: Change kind: \(kind)")
                    if let newMetadata = changeDict[NSKeyValueChangeNewKey] as? [AVMetadataItem] {
                        if kind == NSKeyValueChange.Setting {
                            DDLogInfo("Player: Metadata set: \(newMetadata)")
                            metadataChange(newMetadata)
                        }
                    } else {
                        DDLogWarn("Player: No metaData found.")
                    }
                }
            } else {
                DDLogError("Player: status change invalid \(changeDict[NSKeyValueChangeKindKey])")
            }
        } else {
            DDLogWarn("Player: metaData: no change dictionary?")
        }
    }

    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        if let thisPath = keyPath {
            DDLogDebug("Player: Observed value change for \(thisPath)")
            switch thisPath {
                case "status":
                    if object === _player {
                        observeStatus(ofObject: object, change: change, context: context)
                    } else {
                        DDLogError("Unknown observed object \(object)")
                    }
                case "currentItem.timedMetadata":
                    if object === _player {
                        observeMetadata(ofObject: object, change: change, context: context)
                    } else {
                        DDLogError("Unknown observed object \(object)")
                    }
            default:
                DDLogError("Got value change for unknown: \(thisPath)")
            }
        } else {
            DDLogError("Got nil key for value change")
        }
    }
    
}
