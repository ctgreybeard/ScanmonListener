//
//  LogScrollView.swift
//  ScanmonListener
//
//  Created by William Waggoner on 12/28/15.
//
//


import UIKit
import CocoaLumberjack

/**
 Extend UITextView with appendLine function and provide autoscrolling view
 */
class SMLLogScrollView: UITextView {

    let timeFmt: NSDateFormatter
    let normAttrs: [String: NSObject]
    let timeAttrs: [String: NSObject]
    let dateRange: NSRange

    required init?(coder aDecoder: NSCoder) {
        let fmtString = "ddMMMyy HH:mm:ss"
        let fontSize: CGFloat = 11.0

        timeFmt = NSDateFormatter()
        timeFmt.dateFormat = fmtString

        dateRange = NSMakeRange(0, fmtString.characters.count)

        // Nice Blue (0F68BF, [15, 104, 191], [0.06, 0.41, 0.75])
        let colorNiceBlue = UIColor(red:0.0625, green:0.4106, blue:0.7500, alpha:1.0000)

        normAttrs = [NSForegroundColorAttributeName: UIColor.darkTextColor(),
                     NSFontAttributeName: UIFont.systemFontOfSize(fontSize, weight: UIFontWeightRegular)]
        timeAttrs = [NSForegroundColorAttributeName: colorNiceBlue,
                     NSFontAttributeName: UIFont.monospacedDigitSystemFontOfSize(fontSize - 1.0, weight: UIFontWeightBold)]

        super.init(coder: aDecoder)
        self.text = ""

    }

    /**
     Append the requested string to the view and scroll to the bottom
     
     - parameter line: The string to display as a new line
     */
    func appendLine(line: String) {
        let ts = timeFmt.stringFromDate(NSDate())
        let dString = NSMutableAttributedString(string: "\(ts) \(line)\n", attributes: normAttrs)
        dString.addAttributes(timeAttrs, range: dateRange)
        dString.insertAttributedString(attributedText, atIndex: 0)
        attributedText = dString

        // Scroll to bottom line

        let seeMe = CGRectMake(0.0, contentSize.height - 5.0, 1.0, 1.0)
        DDLogDebug("Bounds: \(bounds), size: \(contentSize), seeMe: \(seeMe)")
        scrollRectToVisible(seeMe, animated: true)
    }
    
}
