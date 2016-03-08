//
//  SettingsViewController.swift
//  ScanmonListener
//
//  Created by William Waggoner on 1/23/16.
//  Copyright © 2016 William C Waggoner. All rights reserved.
//

import UIKit
import CocoaLumberjack

class SettingsViewController: UIViewController {

    @IBOutlet weak var okButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var autoRetrySwitch: UISwitch!
    @IBOutlet weak var backgroundAudioSwitch: UISwitch!
    @IBOutlet weak var disableLockSwitch: UISwitch!

    dynamic var autoRetry: Bool = true
    dynamic var backgroundAudio: Bool = true
    dynamic var disableLock: Bool = true

    override func viewDidLoad() {
        super.viewDidLoad()
        DDLogInfo("Entry")

        autoRetrySwitch.on = autoRetry

        backgroundAudioSwitch.on = backgroundAudio

        disableLockSwitch.on = disableLock
    }

    @IBAction func switchChanged(sender: UISwitch) {
        var switchName: String?

        DDLogInfo("Entry")
        if sender === autoRetrySwitch {
            autoRetry = autoRetrySwitch.on
            switchName = "AutoRetry"
        } else if sender === backgroundAudioSwitch {
            backgroundAudio = backgroundAudioSwitch.on
            switchName = "Background Audio"
        } else if sender === disableLockSwitch {
            disableLock = disableLockSwitch.on
            switchName = "Disable Lock"
        } else {
            DDLogError("Unknown switch setting")
        }

        if let sn = switchName {
            DDLogInfo("Changed: \(sn): \(sender.on)")
        }
    }
}
