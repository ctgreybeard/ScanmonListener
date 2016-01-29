//
//  AppDelegate.swift
//  ScanmonListener
//
//  Created by William Waggoner on 12/28/15.
//  Copyright © 2015 William C Waggoner. All rights reserved.
//

import UIKit
import CoreData
import AVFoundation

import CocoaLumberjack

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, DDLogFormatter {

    var window: UIWindow?
    let avSession = AVAudioSession.sharedInstance()
    let logDateFormat = NSDateFormatter()
    dynamic var preferences: NSUserDefaults! = nil

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {

        // Initialize the date/time formatter
        logDateFormat.dateFormat = "ddMMMyyyy hh:mm:ss.SSS"

        // Initialize the logger
        let testLogLevel = DDLogLevel.Debug

        DDTTYLogger.sharedInstance().logFormatter = self
        DDLog.addLogger(DDTTYLogger.sharedInstance(), withLevel: testLogLevel)

        let fileLogManager = DDLogFileManagerDefault(logsDirectory: applicationDocumentsDirectory.path)
        fileLogManager.maximumNumberOfLogFiles = 5
        let fileLogger = DDFileLogger(logFileManager: fileLogManager)
        fileLogger.maximumFileSize = 10000000
        fileLogger.rollingFrequency = NSTimeInterval(24 * 60 * 60)
        fileLogger.logFormatter = self

        DDTTYLogger.sharedInstance().colorsEnabled = true
        let infoColor = UIColor(red: 0.0, green: 0.5, blue: 0.5, alpha: 1.0)
        DDTTYLogger.sharedInstance().setForegroundColor(infoColor, backgroundColor: nil, forFlag: DDLogFlag.Info)

        loadPrefs()
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "defaultsChanged:", name: NSUserDefaultsDidChangeNotification, object: preferences)

        DDLogDebug("default for backgroundAudio: \(preferences.boolForKey("backgroundAudio"))")

        let fileLogLevel = DDLogLevel(rawValue: UInt(preferences.integerForKey("file_debug"))) ?? DDLogLevel.Info
        DDLogDebug("file_debug: \(fileLogLevel.rawValue)")
        DDLog.addLogger(fileLogger, withLevel: fileLogLevel)

        DDLogInfo("launchOptions:\(launchOptions)")

        DDLogInfo("Documents directory: \(NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true))")
        
        // Establish the Audio Session
        do {
            try avSession.setCategory(AVAudioSessionCategoryPlayback)
            try avSession.setMode(AVAudioSessionModeSpokenAudio)
            try avSession.setActive(false)
        }
        catch {
            DDLogError("audioSession error: \(error))")
        }

        return true
    }

    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
        DDLogDebug("Entry")
    }

    func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        DDLogDebug("Entry")
    }

    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
        DDLogDebug("Entry")
    }

    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        DDLogDebug("Entry")
    }

    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        // Saves changes in the application's managed object context before the application terminates.
        DDLogDebug("Entry")
        self.saveContext()
    }

    func loadPrefs() {
        preferences = NSUserDefaults.standardUserDefaults()

        // Load defaults
        if let defsPath = NSBundle.mainBundle().pathForResource("Defaults", ofType: "plist") {
            if let defStream = NSInputStream(fileAtPath: defsPath) {
                defStream.open()
                do {
                    let defPlist = try NSPropertyListSerialization.propertyListWithStream(defStream, options: .Immutable, format: nil)
                    preferences.registerDefaults(defPlist as! [String : AnyObject])
                } catch {
                    DDLogError("Default properties read error: \(error)")
                }
                defStream.close()
            }
        } else {
            DDLogError("Cannot find Defalts.plist")
        }
    }

    // MARK: - Core Data stack

    lazy var applicationDocumentsDirectory: NSURL = {
        // The directory the application uses to store the Core Data store file. This code uses a directory named "org.greybeard.ScanmonListener" in the application's documents Application Support directory.
        let urls = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)
        return urls[urls.count-1]
    }()

    lazy var managedObjectModel: NSManagedObjectModel = {
        // The managed object model for the application. This property is not optional. It is a fatal error for the application not to be able to find and load its model.
        let modelURL = NSBundle.mainBundle().URLForResource("ScanmonListener", withExtension: "momd")!
        return NSManagedObjectModel(contentsOfURL: modelURL)!
    }()

    lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator = {
        // The persistent store coordinator for the application. This implementation creates and returns a coordinator, having added the store for the application to it. This property is optional since there are legitimate error conditions that could cause the creation of the store to fail.
        // Create the coordinator and store
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
        let url = self.applicationDocumentsDirectory.URLByAppendingPathComponent("SingleViewCoreData.sqlite")
        var failureReason = "There was an error creating or loading the application's saved data."
        do {
            try coordinator.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: url, options: nil)
        } catch {
            // Report any error we got.
            var dict = [String: AnyObject]()
            dict[NSLocalizedDescriptionKey] = "Failed to initialize the application's saved data"
            dict[NSLocalizedFailureReasonErrorKey] = failureReason

            dict[NSUnderlyingErrorKey] = error as NSError
            let wrappedError = NSError(domain: "YOUR_ERROR_DOMAIN", code: 9999, userInfo: dict)
            // Replace this with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            DDLogError("Unresolved error \(wrappedError), \(wrappedError.userInfo)")
            abort()
        }
        
        return coordinator
    }()

    lazy var managedObjectContext: NSManagedObjectContext = {
        // Returns the managed object context for the application (which is already bound to the persistent store coordinator for the application.) This property is optional since there are legitimate error conditions that could cause the creation of the context to fail.
        let coordinator = self.persistentStoreCoordinator
        var managedObjectContext = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = coordinator
        return managedObjectContext
    }()

    // MARK: - Core Data Saving support

    func saveContext () {
        if managedObjectContext.hasChanges {
            do {
                try managedObjectContext.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                DDLogError("Unresolved error \(nserror), \(nserror.userInfo)")
                abort()
            }
        }
    }

    // Private Log formatter
    dynamic func formatLogMessage(l: DDLogMessage!) -> String! {
        let level: String

        switch l.flag {
        case DDLogFlag.Error:
            level = "E"
        case DDLogFlag.Warning:
            level = "W"
        case DDLogFlag.Info:
            level = "I"
        case DDLogFlag.Debug:
            level = "D"
        case DDLogFlag.Verbose:
            level = "V"
        default:
            level = "?"
        }

        return "\(logDateFormat.stringFromDate(l.timestamp)) \(l.fileName)(\(l.line)):\(l.function) -\(level)- \(l.message)"
    }

    // User defaults notification
    dynamic func defaultsChanged(notice: NSNotification) {
        DDLogDebug("Entry: \(notice.name)")
    }
}

