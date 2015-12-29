//
//  LogScrollView.swift
//  ScanmonListener
//
//  Created by William Waggoner on 12/28/15.
//
//

import UIKit

class SMLLogScrollView: UITextView {

    /*
    // Only override drawRect: if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func drawRect(rect: CGRect) {
        // Drawing code
    }
    */

    func appendLine(line: String) {
        self.text = (self.text ?? "") + "\n\(line)"
    }

}
