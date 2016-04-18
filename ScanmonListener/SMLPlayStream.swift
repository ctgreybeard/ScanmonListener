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
    case Retrying = "retrying"
    case Paused = "paused"
    case Stopping = "stopping"
    case Stopped = "stopped"
    case Failed = "failed"
}

class SMLPlayStream: NSObject {

    var _player: AVPlayer?
    let _url: NSURL

    dynamic var player: AVPlayer? {
        return _player
    }

    dynamic var url: NSURL {
        return _url
    }

    dynamic private(set) var statusRaw: String?

    var status: PlayStatus {
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
    private let aSess: AVAudioSession
    private var itemObserver: (NSObject, NSObject)?
    private var audioObserver: (NSObject, NSObject)?

    dynamic var playing: Bool {
        get {
            return status == .Playing
        }
    }

    init(url: NSURL) {
        DDLogInfo("init: \(url.absoluteString)")
        aSess = AVAudioSession.sharedInstance()
        _url = url

        status = .Ready

        super.init()
    }

    func getPlayer(url: NSURL) -> AVPlayer {
        let _asset: AVURLAsset
        let _item: AVPlayerItem
        let _player: AVPlayer

        if player != nil {
            dropPlayer()
        }

        _asset = AVURLAsset(URL: _url)
        _item = AVPlayerItem(asset: _asset)

        _player = AVPlayer(playerItem: _item)
        self._player = _player
        // Set play parameters
        _player.actionAtItemEnd = .Pause

        status = .Starting

        // Set observers
        _item.addObserver(self, forKeyPath: "timedMetadata", options: [.Initial, .New], context: nil)
        _item.addObserver(self, forKeyPath: "status", options: [.Initial, .New], context: nil)
        itemObserver = (self, _item)

        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(SMLPlayStream.audioNotification(_:)), name: nil, object: _item)
        audioObserver = (self, _item)

        return _player
    }

    /**
     Destroys the current AVPlayer instance
     */
    func dropPlayer() {
        removeObservers()
        _player = nil
    }

    /**
     Stop the current AVPlayer before deinitializing
     */
    deinit {
        stop("Deinit")
    }

    /**
     Begin playing the current URL

     - returns: (bool) true if AVPlayer was initialized, false otherwise
     */
    dynamic func play() -> Bool {
        var ok: Bool = false

        DDLogInfo("Player starting")
        if playing {
            stop("Restart")
        }

        getPlayer(_url)

        DDLogInfo("Attempting to play: \(_url.absoluteString)")

        status = .Starting
        logentry = "Starting"

        do {
            try aSess.setActive(true)

            // Set up notifications
            NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(SMLPlayStream.audioNotification(_:)), name: nil, object: aSess)

            ok = true
        }
        catch {
            DDLogError("Audio session set Active failed: \(error)")
        }


        return ok
    }

    /**
     Stop the current item playing

     - parameter reason: Reason description for stop request

     */
    dynamic func stop(reason: String) {
        DDLogInfo("Stopping")
        logentry = "Stopped: \(reason)"

        title = nil
        player?.rate = 0.0
        dropPlayer()

        do {
            try AVAudioSession.sharedInstance().setActive(false)
        }
        catch {
            DDLogError("Audio session set Inactive failed: \(error)")
        }

        status = .Stopped
    }

    /**
     Start the retry process

     - parameter why: Reason description for Retry

     Removes current AVPlayer and retries in 5 seconds
     */
    func retry(why: String) {
        DDLogInfo("Retrying...")
        logentry = "Failed: \(why)"
        dropPlayer()
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(5 * NSEC_PER_SEC)), dispatch_get_main_queue()) {
            self.logentry = "Retrying..."
            self.play()
        }
        status = .Retrying
    }

    /**
     Pause the current player
     */
    dynamic func pause() {
        player?.rate = 0.0
        status = .Paused
    }

    /**
     Resume the current player
     */
    dynamic func resume() {
        player?.rate = 1.0
        status = .Playing
    }

    /**
     Respond to the current AVPlayerItem status change

     - parameter changeObject: AVPlayerItemStatus object value as Int

     */
    func statusChange(changeObject: AnyObject?) -> String? {

        guard let newStatus = changeObject as? Int else {
            return "Status change invalid type: '\(changeObject!)'"
        }

        // Convert Int to AVPlayerItemStatus
        guard let itemStatus = AVPlayerItemStatus(rawValue: newStatus) else {
            return "Invalid AVPlayerItemStatus value: '\(newStatus)'"
        }

        var error: String? = nil

        DDLogDebug("Status change")

        switch itemStatus {
        case .Unknown:
            error = "Status change to 'Unknown'"

        case .ReadyToPlay:
            DDLogInfo("status change to ReadyToPlay")
            _player!.rate = 1.0
            timeObserver = self._player!.addPeriodicTimeObserverForInterval(CMTime(seconds: 1.0, preferredTimescale: 1), queue: nil) {
                (time: CMTime) in self.time = time.seconds
            }
            logentry = "Playing"
            status = .Playing

        case .Failed:
            DDLogInfo("status change to Failed: \(_player?.currentItem?.error!)")
            let failMsg = _player?.currentItem?.error?.localizedDescription ?? "Unknown"
            logentry = "Failed: \(failMsg)"
            status = .Failed
        }

        return error
    }

    /**
     Parse metadataChange and set self.title if the title is found

     - parameter changeObject: AVMetaDataItem object
     */
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

    /**
    Parse change dictionary and pass New change object to the designated handler

    - parameters:

        - change: Supplied change dictionary

        - handler: Designated change handler
     */
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

        let result: String?

        switch thisPath {
        case "status":
            result = observeChange(change, handler: statusChange)

        case "timedMetadata":
            result = observeChange(change, handler: metadataChange)

        default:
            result = "KeyValueChange got value change for unknown key: '\(thisPath)'"

        }

        if result != nil {
            DDLogError("\(result!) for key change: \(thisPath)")
        }
    }

    func streamFailed(reason: String) {

        if NSUserDefaults.standardUserDefaults().boolForKey("autoRetry") {
            dispatch_async(dispatch_get_main_queue()) {
                self.retry(reason)
            }
        } else {
            dispatch_async(dispatch_get_main_queue()) {
                self.stop(reason)
            }
        }
    }

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

        switch name {
        case AVFoundation.AVAudioSessionRouteChangeNotification:
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
            DDLogDebug("audioNotification: current rate: \(_player?.rate)")

            if _player?.rate == 0.0 {
                dispatch_async(dispatch_get_main_queue(), {
                    self.stop("Output changed")
                })
            }

        case AVFoundation.AVPlayerItemDidPlayToEndTimeNotification:        // Source was killed or client kicked
            streamFailed("At end")

        case AVFoundation.AVPlayerItemFailedToPlayToEndTimeNotification:   // Lost the connection?
            var reason = "Detected end"
            DDLogWarn(reason)
            if let thisError = userInfo[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? NSError {
                reason = thisError.localizedDescription
                DDLogWarn("Error Info: \(thisError.userInfo)")
            }
            streamFailed(reason)

        case AVFoundation.AVPlayerItemPlaybackStalledNotification:          // Network error?
            logentry = "Detected Stall"
            DDLogWarn(logentry!)

        case AVFoundation.AVAudioSessionInterruptionNotification:

            let tvalue = userInfo[AVAudioSessionInterruptionTypeKey] as! NSNumber

            guard let type =  AVAudioSessionInterruptionType(rawValue: UInt(tvalue)) else {
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
            
        default:
            DDLogWarn("Unhandled Notification: \(name)")
        }
    }
    
    func removeObservers() {
        if let (io, ii) = itemObserver {
            ii.removeObserver(io, forKeyPath: "timedMetadata")
            ii.removeObserver(io, forKeyPath: "status")
            itemObserver = nil
        }
        
        if let to = timeObserver {
            player?.removeTimeObserver(to)
            timeObserver = nil
        }
        
        if let (ao, _) = audioObserver {
            NSNotificationCenter.defaultCenter().removeObserver(ao)
            audioObserver = nil
        }
    }
    
}
