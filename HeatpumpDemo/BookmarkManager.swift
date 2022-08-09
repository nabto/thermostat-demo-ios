//
//  BookmarkManager.swift
//  HeatpumpDemo
//
//  Created by Nabto on 03/02/2022.
//  Copyright © 2022 Nabto. All rights reserved.
//

import UIKit

struct Bookmark : Equatable, Hashable, CustomStringConvertible {
    let deviceId: String
    var productId: String
    var sct: String?
    var name : String?
    var modelName: String?

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
        "Bookmark(deviceId: \(deviceId), productId: \(productId), sct: \(sct), name: \(name))"
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
        self.deviceBookmarks.append(Bookmark(deviceId: "de-ijrdq47i", productId: "pr-fatqcwj9", sct: "WzwjoTabnvux", name: "Stub device"))
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
