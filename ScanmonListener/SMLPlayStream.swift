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
}

class SMLPlayStream: NSObject {

    var _player: AVPlayer?
    var _url: NSURL?
    
    dynamic private(set) var statusRaw: String?

    var status: PlayStatus = .Ready {
        didSet {
            statusRaw = status.rawValue
        }
    }

    dynamic var title: String?

//    override class func automaticallyNotifiesObserversForKey(key: String) -> Bool {
//        var automatic: Bool = true
//
//        if key == "status" {
//            automatic = false
//        } else {
//            automatic = super.automaticallyNotifiesObserversForKey(key)
//        }
//
//        return automatic
//    }
//
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
            newPlayer.addObserver(self, forKeyPath: "status", options: .New, context: nil)
            newPlayer.addObserver(self, forKeyPath: "currentItem.timedMetadata", options: .New, context: nil)
            status = .Starting
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
        _player = nil
//        self.setValue(PlayStatus.Stopped.rawValue, forKey: "status")
        status = .Stopped
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
        switch status {
        case .Unknown:
            DDLogInfo("Player: status change to Unknown")
        case .ReadyToPlay:
            DDLogInfo("Player: status change to ReadyToPlay")
            _player?.play()
//            self.setValue(PlayStatus.Playing.rawValue, forKey: "status")
            self.status = .Playing
        case .Failed:
            DDLogInfo("Player: status change to Failed: \(_player?.error)")
        }
    }

    func metadataChange(data: [AVMetadataItem]) {

    }

    func observeStatus(ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
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
        }
    }

    func observeMetadata(ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        if let changeDict = change {
            if let kindNum = changeDict[NSKeyValueChangeKindKey] as? NSNumber {
                if let kind = NSKeyValueChange(rawValue: UInt(kindNum)) {
                    if let newVal = changeDict[NSKeyValueChangeNewKey] {
                        let newMetadata = newVal as! [AVMetadataItem]
                        if kind == NSKeyValueChange.Setting {
                            DDLogInfo("Player: Metadata set: \(newMetadata)")
                            metadataChange(newMetadata)
                        }
                    }
                }
            } else {
                DDLogError("Player: status change invalid \(changeDict[NSKeyValueChangeKindKey])")
            }
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
