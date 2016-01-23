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
    case Paused = "paused"
    case Stopping = "stopping"
    case Stopped = "stopped"
    case Failed = "failed"
}

class SMLPlayStream: NSObject {

    var _player: AVPlayer?
    var _url: NSURL?

    dynamic private(set) var statusRaw: String?

    var status: PlayStatus = .Ready {
        didSet {
            DDLogDebug("status set: \(status.rawValue)")
            statusRaw = status.rawValue
        }
    }

    dynamic var title: String?
    dynamic var time: NSNumber?
    dynamic var logentry: String?

    // Private instance variables
    private var timeObserver: AnyObject?
    let aSess = AVAudioSession.sharedInstance()

    dynamic func audioNotification(note: NSNotification) {

        DDLogDebug("audioNotification: name: '\(note.name)'")
        let name = note.name

        DDLogDebug("audioNotification: object: '\(note.object!)'")

        var userInfo: [NSObject: AnyObject]
        if note.userInfo != nil {
            DDLogDebug("audioNotification: userinfo: '\(note.userInfo!)'")
            userInfo = note.userInfo!
        } else {
            userInfo = [NSObject: AnyObject]()
        }

        if name == AVFoundation.AVAudioSessionRouteChangeNotification {
            guard let reasonNum = userInfo[AVFoundation.AVAudioSessionRouteChangeReasonKey] as? NSNumber else {
                DDLogError("audioNotification: ChangeReason not valid: \(userInfo["AVAudioSessionRouteChangeReasonKey"])")
                return
            }

            guard let reason = AVAudioSessionRouteChangeReason(rawValue: UInt(reasonNum)) where reasonNum.intValue >= 0  else {
                DDLogError("audioNotification: ChangeReason not valid")
                return
            }

            DDLogDebug("audioNotification: reason: \(reason) (\(reason.rawValue))")

            var oldRoute = "Unknown"
            var newRoute = "Unknown"

            if let oldDesc = userInfo[AVFoundation.AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription {
                if oldDesc.outputs.count > 0 {
                    oldRoute = oldDesc.outputs[0].portName
                }
            }

            let newDesc = AVAudioSession.sharedInstance().currentRoute
            if newDesc.outputs.count > 0 {
                newRoute = newDesc.outputs[0].portName
            }

            DDLogDebug("audioNotification: route change: old: \(oldRoute), new: \(newRoute)")

            // AVPlayer maybe pauses on audio route change (unplug headset, etc.)
            DDLogDebug("audioNotification: current rate: \(_player!.rate)")

            if _player!.rate == 0.0 {
                dispatch_async(dispatch_get_main_queue(), {
                    self.stop("Output changed")
                })
            }

        } else if name == AVFoundation.AVPlayerItemDidPlayToEndTimeNotification ||        // Source was killed or client kicked
            name == AVFoundation.AVPlayerItemFailedToPlayToEndTimeNotification ||   // Lost the connection?
            name == AVFoundation.AVPlayerItemPlaybackStalledNotification {          // Network error?

                // Lost the stream somehow
                dispatch_async(dispatch_get_main_queue(), {
                    self.stop(note.name)
                })

        } else if name == AVFoundation.AVAudioSessionInterruptionNotification {

            guard let type = userInfo[AVAudioSessionInterruptionTypeKey] as? AVAudioSessionInterruptionType else {
                DDLogError("Interruption type not valid: \(userInfo[AVAudioSessionInterruptionTypeKey])")
                return
            }

            let typeDesc: String
            switch type {
            case .Began:
                typeDesc = "Began"
            case .Ended:
                typeDesc = "Ended"
            }
            DDLogInfo("Interruption type: \(typeDesc), our status: \(status.rawValue), player status: \(_player?.status.rawValue)")

            switch type {
            case .Began:
                if status == .Playing {
                    status = .Paused
                }

            case .Ended:
                if let option = userInfo[AVAudioSessionInterruptionOptionKey] as? AVAudioSessionInterruptionOptions {
                    switch option {
                    case AVAudioSessionInterruptionOptions.ShouldResume:
                        status = .Playing
                        _player?.play()
                    default:
                        DDLogError("Unknown interruption option: \(option.rawValue)")
                    }
                } else {
                    DDLogError("No options found in interruption")
                }
            }

        } else {
            DDLogWarn("Unhandled Notification: \(name)")
        }
    }

    dynamic func play(url: String) -> Bool {
        var ok: Bool = false

        DDLogInfo("Player starting: \(url)")
        if playing {
            stop("Restart")
        }

        if let newURL = NSURL(string: url) {
            self.url = newURL
            DDLogInfo("Attempting to play: \(newURL)")

            status = .Starting

            let newPlayer = AVPlayer(URL: newURL)
            _player = newPlayer

            // Set play parameters
            newPlayer.actionAtItemEnd = .Pause


            // Set observers
            newPlayer.addObserver(self, forKeyPath: "status", options: [.Initial, .New], context: nil)
            newPlayer.addObserver(self, forKeyPath: "currentItem.timedMetadata", options: [.Initial, .New], context: nil)
            timeObserver = newPlayer.addPeriodicTimeObserverForInterval(CMTime(seconds: 1.0, preferredTimescale: 1), queue: nil, usingBlock: {(time: CMTime) in
                self.time = time.seconds
            })

            do {
                try aSess.setActive(true)

                // Set up notifications
                NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("audioNotification:"), name: nil, object: aSess)
                if _player?.currentItem != nil {
                    NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("audioNotification:"), name: nil, object: _player!.currentItem!)
                }

                ok = true
            }
            catch {
                DDLogError("Audio session set Active failed: \(error)")
            }

        } else {
            DDLogError("Create URL failed")
        }

        return ok
    }

    dynamic func stop(reason: String) {
        DDLogInfo("Stopping")
        logentry = "Stopped: \(reason)"

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
            DDLogError("Audio session set Inactive failed: \(error)")
        }
    }

    dynamic var playing: Bool {
        get {
            return status == .Playing
        }
    }

    dynamic var url: NSURL? {
        get {
            return _url
        }

        set(newURL) {
        }
    }

    func statusChange(changeObject: AnyObject?) -> String? {
        guard let newStatus = changeObject as? Int else {
            return "Status change invalid type: '\(changeObject!)'"
        }

        DDLogDebug("statusChange")

        guard let status = AVPlayerStatus(rawValue: newStatus) else {
            return "Invalid AVPlayerStatus value: '\(newStatus)'"
        }

        let error: String?

        switch status {
        case .Unknown:
            error = "Status change to 'Unknown'"

        case .ReadyToPlay:
            DDLogInfo("status change to ReadyToPlay")
            _player?.play()
            self.status = .Playing
            error = nil

        case .Failed:
            DDLogInfo("status change to Failed: \(_player?.error!)")
            self.status = .Failed
            error = nil
        }

        return error
    }

    func metadataChange(changeObject: AnyObject?) -> String? {
        guard let data = changeObject as? [AVMetadataItem] else {
            return "Metadata change invalid type: '\(changeObject!)'"
        }

        DDLogDebug("metadataChange")

        // Loop through the metadata looking for the title
        for md in AVMetadataItem.metadataItemsFromArray(data, withKey: "title", keySpace: "comn") {
            if let realTitle = md.stringValue {
                title = realTitle
                DDLogInfo("Set title: '\(realTitle)'")
            } else {
                DDLogWarn("Unexpected value for title: '\(md.value!)', type=\(md.dataType!)")
            }
        }

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
            return "KeyValueChange change kind invalid: '\(kindNum.stringValue)'"
        }

        guard kind == NSKeyValueChange.Setting else {
            return "KeyValueChange unexpected change kind: '\(kind)'"
        }

        // Working code begins here ...
        return handler(changeDict[NSKeyValueChangeNewKey])
    }

    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {

        guard let thisPath = keyPath else {
            DDLogError("Got nil key for value change")
            return
        }

        guard object === _player else {
            DDLogError("Unknown observed object '\(object!)'")
            return
        }
        
        let result: String?
        
        switch thisPath {
        case "status":
            result = observeChange(change, handler: statusChange)
            
        case "currentItem.timedMetadata":
            result = observeChange(change, handler: metadataChange)
            
        default:
            result = "KeyValueChange got value change for unknown key '\(thisPath)'"
            
        }
        if result != nil {
            DDLogError("\(result!) for key change: \(thisPath)")
        }
    }
}
