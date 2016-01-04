//
//  LogScrollView.swift
//  ScanmonListener
//
//  Created by William Waggoner on 12/28/15.
//
//

import UIKit

class SMLLogScrollView: UITextView {

    func appendLine(line: String) {
        text = (self.text ?? "") + "\(line)\n"
    }

}
