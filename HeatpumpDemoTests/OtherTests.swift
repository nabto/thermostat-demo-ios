//
//  ios_starter_nabtoTests.swift
//  HeatpumpDemoTests
//
//  Created by Nabto on 30/01/2022.
//  Copyright © 2022 Nabto. All rights reserved.
//

import XCTest
//@testable import ios_starter_nabto

class OtherTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testBookmarkSaving() {
        let bookmark1 = Bookmark(deviceId: "kzspcxu3.gygkd.appmyproduct.com", productId: "TBD", name: "AMP stub")
        let bookmark2 = Bookmark(deviceId: "kzspcxu4.gygkd.appmyproduct.com", productId: "TBD", name: "AMP stub2")
        BookmarkManager.shared.add(bookmark: bookmark1)
        BookmarkManager.shared.add(bookmark: bookmark2)
        BookmarkManager.shared.saveBookmarks()
        BookmarkManager.shared.deviceBookmarks = []
        
        BookmarkManager.shared.loadBookmarks()
        let savedBookmarks = BookmarkManager.shared.deviceBookmarks
        XCTAssert(savedBookmarks.count == 2)
        
        let saved1 = savedBookmarks[0]
        let saved2 = savedBookmarks[1]
        XCTAssert(bookmark1 == saved1)
        XCTAssert(bookmark2 == saved2)
        XCTAssert(bookmark1.name == saved1.name)
        XCTAssert(bookmark2.name == saved2.name)
        
        BookmarkManager.shared.clearBookmarks()
        BookmarkManager.shared.loadBookmarks()
        XCTAssert(BookmarkManager.shared.deviceBookmarks.count == 0)
    }
    
    func testFingerprintFormatting() {
        let string = "6074fce148dd2dd6b39106fbf4b99dbd"
        let formatted = UserInfo.format(fingerprint: string)
        XCTAssert(formatted == "60:74:fc:e1:48:dd:2d:d6:b3:91:06:fb:f4:b9:9d:bd")
    }
}
