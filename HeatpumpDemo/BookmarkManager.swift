//
//  BookmarkManager.swift
//  HeatpumpDemo
//
//  Created by Tiago Lira on 03/02/2017.
//  Copyright © 2017 Nabto. All rights reserved.
//

import UIKit

struct Bookmark : Equatable {
    let id   : String
    var name : String?
    
    static func ==(b1: Bookmark, b2: Bookmark) -> Bool {
        return b1.id == b2.id
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
        let dictionary = deviceBookmarks.map { return ["id" : $0.id, "name" : $0.name] }
        do {
            let data = try PropertyListSerialization.data(fromPropertyList: dictionary,
                                                          format: .xml, options: 0)
            try data.write(to: url, options: .atomic)
        } catch {
            print("error writing bookmarks file")
        }
    }
    
    func loadBookmarks() {
        let url = bookmarksFileURL()
        do {
            let data = try Data(contentsOf: url)
            let result = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
            if let dict = result as? [[String : String?]] {
                deviceBookmarks = dict.map { return Bookmark(id: $0["id"]!!, name: $0["name"]!) }
            }
        } catch {
            print("error reading bookmarks file")
        }
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
