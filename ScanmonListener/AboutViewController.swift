//
//  AboutViewController.swift
//  ScanmonListener
//
//  Created by William Waggoner on 1/23/16.
//  Copyright © 2016 William C Waggoner. All rights reserved.
//

import UIKit

class AboutViewController: UIViewController {

    @IBOutlet weak var version: UILabel!
    override func viewDidLoad() {
        super.viewDidLoad()

        let bundle = NSBundle.mainBundle()
        let version = bundle.objectForInfoDictionaryKey("CFBundleShortVersionString") as! String
        let build = bundle.objectForInfoDictionaryKey("CFBundleVersion") as! String
        self.version.text = "\(version) (\(build))"
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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
