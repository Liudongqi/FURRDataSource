// swiftlint:disable line_length
//
//  DataSourceEngineTests.swift
//  FURRDataSource
//
//  Created by Ruotger Deecke on 26.12.15.
//  Copyright © 2015-2016 Ruotger Deecke. All rights reserved.
//
//
// TL/DR; BSD 2-clause license
//
// Redistribution and use in source and binary forms, with or without modification, are permitted provided that the
// following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following
//    disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the
//    following disclaimer in the documentation and/or other materials provided with the distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
// INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
// WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


import XCTest

class DataSourceEngineTests: XCTestCase {

    var engine = DataSourceEngine<MockTVItem>()

    #if swift(>=3.0)
    var insertionRowIndexPaths: [IndexPath] = []
    var deletionRowIndexPaths: [IndexPath] = []
    var insertionSectionIndexSet: IndexSet = IndexSet()
    var deletionSectionIndexSet: IndexSet = IndexSet()
    #else
    var insertionRowIndexPaths: [NSIndexPath] = []
    var deletionRowIndexPaths: [NSIndexPath] = []
    var insertionSectionIndexSet: NSIndexSet = NSMutableIndexSet()
    var deletionSectionIndexSet: NSIndexSet = NSMutableIndexSet()
    #endif

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        self.engine = DataSourceEngine<MockTVItem>()
        self.engine.beginUpdates = {}
        self.engine.endUpdates = {}
        self.engine.deleteSections = { indexSet in self.deletionSectionIndexSet = indexSet }
        self.engine.insertSections = { indexSet in self.insertionSectionIndexSet = indexSet }
        self.engine.insertRowsAtIndexPaths = { indexPathArray in
            #if swift(>=3.0)
                self.insertionRowIndexPaths.append(contentsOf: indexPathArray)
            #else
                self.insertionRowIndexPaths.appendContentsOf(indexPathArray)
            #endif
        }
        self.engine.deleteRowsAtIndexPaths = { indexPathArray in
            #if swift(>=3.0)
                self.deletionRowIndexPaths.append(contentsOf: indexPathArray)
            #else
                self.deletionRowIndexPaths.appendContentsOf(indexPathArray)
            #endif
        }
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testDataSourceSections() {

        var sections = ["a", "b", "c"]
        self.engine.update(sections: sections, animated: true)
        self.thenNumberOfSectionsIs(3)
        XCTAssert(sections == (self.engine.sections()))

        // test whether it's actually const
        sections = ["a", "b", "c", "d"]
        XCTAssert(sections != (engine.sections()))

        self.engine.update(sections: ["a", "d", "c"], animated: true)
        self.thenNumberOfSectionsIs(3)

        self.engine.update(sections: ["a", "d", "c", "e"], animated: true)
        self.thenNumberOfSectionsIs(4)

        self.engine.update(sections: [], animated: true)
        self.thenNumberOfSectionsIs(0)

        var didFail = false
        self.engine.fail = { (msg) -> Void in didFail = true }

        self.engine.update(sections: ["a", "a", "a"], animated: true)
        XCTAssert(didFail)
    }

    func testDataSourceRows() {
        var didWarn = false
        self.engine.warn = { (message: String?) -> Void in
            didWarn = true
        }

        // trying to update non-existing section
        self.whenUpdatingRows(identifiers: ["0", "1", "2"], sectionID: "a")
        XCTAssert(didWarn)

        self.whenUpdatingSections(withIDs: ["a", "b", "c"])
        self.thenNumberOfSectionsIs(3)

        self.whenUpdatingRows(identifiers: ["0", "1", "2"], sectionID: "a")

        self.thenNumberOfRowsIs(3, sectionIndex: 0)
        self.thenInsertionRowsSectionsAre(indexPaths: [[0, 0], [1, 0], [2, 0]])
        self.thenDeletionRowsSectionsAre(indexPaths: [])
        XCTAssert(MockTVItem.mockTVItems(identifiers: ["0", "1", "2"]) == (self.engine.rows(forSection: "a")))

        self.givenDiffsAreCleared()

        self.whenUpdatingRows(identifiers: ["0", "2", "3"], sectionID: "a")
        self.thenNumberOfSectionsIs(3)
        self.thenInsertionRowsSectionsAre(indexPaths: [[2, 0]])
        self.thenDeletionRowsSectionsAre(indexPaths: [[1, 0]])

        var didFail = false
        self.engine.fail = { (msg) -> Void in didFail = true }
        self.whenUpdatingRows(identifiers: ["0", "0", "0"], sectionID: "a")
        XCTAssert(didFail)
    }

    func testDataSourceRowsDelete() {
        self.whenUpdatingSections(withIDs: ["a", "b", "c"])
        self.thenNumberOfSectionsIs(3)

        self.whenUpdatingRows(identifiers: ["0", "1", "2"], sectionID: "a")
        self.givenDiffsAreCleared()

        self.whenUpdatingRows(identifiers: ["0", "5", "4", "2"], sectionID: "a")
        self.thenNumberOfRowsIs(4, sectionIndex: 0)
        self.thenInsertionRowsSectionsAre(indexPaths: [[1, 0], [2, 0]])
        self.thenDeletionRowsSectionsAre(indexPaths: [[1, 0]])

        self.givenDiffsAreCleared()

        print("")

        self.whenUpdatingRows(identifiers: ["0", "2"], sectionID: "a")
        self.thenNumberOfRowsIs(2, sectionIndex: 0)
        self.thenInsertionRowsSectionsAre(indexPaths: [])
        self.thenDeletionRowsSectionsAre(indexPaths: [[1, 0], [2, 0]])

        self.givenDiffsAreCleared()

        self.whenUpdatingRows(identifiers: ["0", "1", "2", "3", "4", "5"], sectionID: "a")
        self.givenDiffsAreCleared()

        self.whenUpdatingRows(identifiers: ["0", "2", "4"], sectionID: "a")
        self.thenNumberOfRowsIs(3, sectionIndex: 0)
        self.thenInsertionRowsSectionsAre(indexPaths: [])
        self.thenDeletionRowsSectionsAre(indexPaths: [[1, 0], [3, 0], [5, 0]])
    }

    func testDataSourceWhenCompletelyEmpty() {

        self.thenNumberOfSectionsIs(0)

        // note: asking for the number of rows in section 0 would result in a fail as we don't have a sectionID.
    }

    // MARK: - given

    func givenDiffsAreCleared() {
        self.deletionRowIndexPaths = []
        self.insertionRowIndexPaths = []
        #if swift(>=3.0)
            self.insertionSectionIndexSet = IndexSet()
            self.deletionSectionIndexSet = IndexSet()
        #else
            self.insertionSectionIndexSet = NSMutableIndexSet()
            self.deletionSectionIndexSet = NSMutableIndexSet()
        #endif
    }

    // MARK: - when

    func whenUpdatingSections(withIDs inSectionIDs: Array<String>) {
        self.engine.update(sections: inSectionIDs, animated: true)
    }

    func whenUpdatingRows(identifiers rowIdentifiers: [String], sectionID: String) {
        self.engine.update(rows: MockTVItem.mockTVItems(identifiers: rowIdentifiers), section: sectionID, animated: true)
    }

    // MARK: - then

    func thenNumberOfSectionsIs(_ numberOfSections: Int) {
        XCTAssert(engine.sections().count == numberOfSections, "...")
    }

    func thenNumberOfRowsIs(_ numberOfRows: Int, sectionIndex: Int) {
        if let sectionIDAndRows = engine.sectionIDAndRows(forSectionIndex: sectionIndex) {
            XCTAssert(sectionIDAndRows.1.count == numberOfRows)
        } else {
            XCTFail()
        }
    }

    func thenInsertionRowsSectionsAre(indexPaths inIndexPaths: [[Int]]) {
        let realIndexPaths = inIndexPaths.map(testHelper_indexListMapper())

        XCTAssert(self.insertionRowIndexPaths == realIndexPaths)
    }
    
    func thenDeletionRowsSectionsAre(indexPaths: [[Int]]) {
        let realIndexPaths = indexPaths.map(testHelper_indexListMapper())
        
        XCTAssert(self.deletionRowIndexPaths == realIndexPaths)
    }
    
}
