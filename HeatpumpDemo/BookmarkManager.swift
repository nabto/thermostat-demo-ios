//
//  BookmarkManager.swift
//  HeatpumpDemo
//
//  Created by Nabto on 03/02/2022.
//  Copyright © 2022 Nabto. All rights reserved.
//

import UIKit

class Bookmark : Equatable, Hashable, CustomStringConvertible {
    let deviceId: String
    let productId: String
    var timeAdded: Date
    var sct: String?
    var name : String = "Anonymous Heatpump"
    var modelName: String?
    var role: String?

    func hash(into hasher: inout Hasher) {
        hasher.combine(deviceId)
        hasher.combine(productId)
    }

    static func ==(lhs: Bookmark, rhs: Bookmark) -> Bool {
        if lhs.deviceId != rhs.deviceId {
            return false
        }
        if lhs.productId != rhs.productId {
            return false
        }
        return true
    }

    var description: String {
        "Bookmark(deviceId: \(deviceId), productId: \(productId), timeAdded: \(timeAdded), sct: \(sct), name: \(name), modelName: \(modelName), role: \(role))"
    }

    init(deviceId: String, productId: String, creationTime: Date, sct: String?=nil, name: String?=nil, modelName: String?=nil, role: String?=nil) {
        self.deviceId = deviceId
        self.productId = productId
        self.timeAdded = creationTime
        self.sct = sct
        if let name = name {
            self.name = name
        }
        self.modelName = modelName
        self.role = role
    }
}

class BookmarkManager {

    static let shared = BookmarkManager()
    private init() {
        loadBookmarks()
    }
    
    var deviceBookmarks: [Bookmark] = []

    func add(bookmark: Bookmark) {
        if !deviceBookmarks.contains(bookmark){
            bookmark.timeAdded = Date()
            deviceBookmarks.append(bookmark)
            saveBookmarks()
        }
    }
    
    func saveBookmarks() {
        let url = bookmarksFileURL()
        let dictionary = deviceBookmarks.map { return ["deviceId" : $0.deviceId, "productId": $0.productId, "name" : $0.name] }
        do {
            let data = try PropertyListSerialization.data(fromPropertyList: dictionary,
                                                          format: .xml, options: 0)
            try data.write(to: url, options: .atomic)
        } catch {
            print("error writing bookmarks file")
        }
    }
    
    func loadBookmarks() {
//        let url = bookmarksFileURL()
//        do {
//            let data = try Data(contentsOf: url)
//            let result = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
//            if let dict = result as? [[String : String?]] {
//                deviceBookmarks = dict.map { return Bookmark(
//                        deviceId: $0["deviceId"]!!, productId: $0["productId"]!!, name: $0["name"]!)
//                }
//            }
//        } catch {
//            print("error reading bookmarks file")
//        }
        var bookmarks: [Bookmark] = []
        bookmarks.append(Bookmark(deviceId: "de-xxxxxxxx", productId: "pr-fatqcwj9", creationTime: Date(timeIntervalSince1970: 0), sct: "WzwjoTabnvux", name: "Offline device (top)"))
        bookmarks.append(Bookmark(deviceId: "de-ijrdq47i", productId: "pr-fatqcwj9", creationTime: Date(timeIntervalSince1970: 1), sct: "WzwjoTabnvux", name: "Remote integration test"))
//        bookmarks.append(Bookmark(deviceId: "de-3cqgxbdm", productId: "pr-cc9i4y7r", creationTime: Date(timeIntervalSince1970: 2), name: "Local heatpump"))
        bookmarks.append(Bookmark(deviceId: "de-yyyyyyyy", productId: "pr-fatqcwj9", creationTime: Date(timeIntervalSince1970: 3), sct: "WzwjoTabnvux", name: "Offline device (bottom)"))
        self.deviceBookmarks = bookmarks.sorted(by: { $0.timeAdded < $1.timeAdded })
    }
    
    func clearBookmarks() {
        let url = bookmarksFileURL()
        deviceBookmarks = []
        
        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(atPath: url.path)
        }
    }
    
    func bookmarksFileURL() -> URL {
        let directory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        return URL(fileURLWithPath: directory).appendingPathComponent("bookmarks.plist")
    }
}
