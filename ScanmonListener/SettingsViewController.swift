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

        autoRetrySwitch.on = autoRetry

        backgroundAudioSwitch.on = backgroundAudio

        disableLockSwitch.on = disableLock
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func switchChanged(sender: UISwitch) {
        autoRetry = autoRetrySwitch.on
        backgroundAudio = backgroundAudioSwitch.on
        disableLock = disableLockSwitch.on
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
