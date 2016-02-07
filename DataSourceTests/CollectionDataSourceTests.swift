//
//  CollectionDataSourceTests.swift
//  FURRDataSource
//
//  Created by Ruotger Deecke on 14.01.16.
//  Copyright © 2016 Ruotger Deecke. All rights reserved.
//

// test files can be longer, right?
// swiftlint:disable file_length


import XCTest

class CollectionDataSourceTests: BaseDataSourceTests {

    var collectionView: MockCollectionView? = nil
    var dataSource: CollectionDataSource<MockTVItem>? = nil
    var didCallDidSelectHandler = false

    // MARK: - helper

    func cellForSectionID(sectionID: String, item inItem: MockTVItem, collectionView inCollectionView: UICollectionView) -> UICollectionViewCell {
        guard let dataSource = self.dataSource else {
            XCTFail("no data source")
            return UICollectionViewCell() // <-- will fail anyway
        }
        let cell = dataSource.dequeueReusableCellWithReuseIdentifier("Cell", sectionID: sectionID, item: inItem)

        if let cell_ = cell {
            return cell_
        } else {
            return UICollectionViewCell() // <-- will fail anyway
        }
    }

    override func sections() -> [String] {
        guard let dataSource = self.dataSource else {
            XCTFail("no data source")
            return [] // <-- will fail anyway
        }

        return dataSource.sections()
    }

    override func rowsForSection(section: String) -> [MockTVItem] {
        guard let dataSource = self.dataSource else {
            XCTFail("no data source")
            return [] // <-- will fail anyway
        }

        return dataSource.rowsForSection(section)
    }

    override func setFailFunc(failFunc: (String) -> Void) {
        guard let dataSource = self.dataSource else {
            XCTFail("no data source")
            return
        }

        dataSource.setFailFunc(failFunc)
    }

    override func setWarnFunc(warnFunc: (String) -> Void) {
        guard let dataSource = self.dataSource else {
            XCTFail("no data source")
            return
        }

        dataSource.setWarnFunc(warnFunc)
    }

    // MARK: - given

    override func givenDelegateAndDataSource() {
        let collectionViewLayout = UICollectionViewFlowLayout()
        self.collectionView = MockCollectionView(frame: CGRect(x: 0, y: 0, width: 320, height: 960), collectionViewLayout: collectionViewLayout)
        self.collectionView?.registerClass(MockCollectionViewCell.classForKeyedUnarchiver(), forCellWithReuseIdentifier: "Cell")
        guard let collectionView = self.collectionView else {
            XCTFail("could not instantiate table view")
            return
        }
        self.dataSource = CollectionDataSource<MockTVItem>(collectionView: collectionView) { (inLocation: Location<MockTVItem>) -> UICollectionViewCell in
            self.cellForSectionID(inLocation.sectionID, item: inLocation.item, collectionView: collectionView)
        }
        self.dataSource?.setReportingLevel(.PreCondition)

        collectionView.insertRowsCallback = { print("insert rows \($0)") }
        collectionView.deleteRowsCallback = { print("delete rows \($0)") }
        collectionView.insertSectionsCallback = { print("insert sections \($0)") }
        collectionView.deleteSectionsCallback = { print("delete sections \($0)") }
        didCallDidSelectHandler = false
    }

    override func givenDiffsAreCleared() {
        guard let collectionView = self.collectionView else {
            XCTFail("no table view")
            return
        }
        collectionView.deletionRowIndexPaths = []
        collectionView.insertionRowIndexPaths = []
        collectionView.insertionSectionIndexSet = NSMutableIndexSet()
        collectionView.deletionSectionIndexSet = NSMutableIndexSet()
    }

    override func givenWillAllowSelectInSectionID(sectionID: String, rowID inRowID: String) {
        guard let dataSource = self.dataSource else {
            XCTFail("no data source")
            return
        }
        didCallDidSelectHandler = false
        dataSource.didSelect = { (inLocation: Location<MockTVItem>) -> Void in
            XCTAssert(inLocation.sectionID == "a")
            XCTAssert(inLocation.item.identifier == "1")
            self.didCallDidSelectHandler = true
        }
    }

    func givenCanMoveItemAtSectionID(inSectionID: String, rowID inRowID: String) {
        guard let dataSource = self.dataSource else {
            XCTFail("no data source")
            return
        }
        dataSource.canMove = {(toLocation: Location<MockTVItem>) -> Bool in
            return toLocation.sectionID == inSectionID && toLocation.item.identifier == inRowID
        }
    }

    func givenExpectRowIDsAfterMove(rowIDs: [String], forSectionID sectionID: String, withSectionCount sectionCount: Int) {
        guard let dataSource = self.dataSource else {
            XCTFail("no data source")
            return
        }
        dataSource.setDidChangeSectionIDsFunc({ (inSectionIDs: Dictionary<String, Array<MockTVItem>>) -> Void in
            XCTAssert(inSectionIDs.count == sectionCount)

            guard let rows = inSectionIDs[sectionID] else {
                XCTFail("no rows?")
                return
            }

            let mappedIDs = rows.map({ (item) -> String in
                return item.identifier
            })

            XCTAssert(mappedIDs == rowIDs)
        })
    }
    // MARK: - when

    override func whenUpdatingSectionIDs(inSectionIDs: Array<String>) {
        guard let dataSource = self.dataSource else {
            XCTFail("no data source")
            return
        }
        dataSource.updateSections(inSectionIDs, animated: true)
    }

    override func whenUpdatingRowsWithIdentifiers(identifiers: [String], sectionID: String) {
        guard let dataSource = self.dataSource else {
            XCTFail("no data source")
            return
        }

        dataSource.updateRows(MockTVItem.mockTVItemsForIdentifiers(identifiers), section: sectionID, animated: true)
    }

    override func whenSelectingRow(row: Int, section: Int) {
        guard let dataSource = self.dataSource else {
            XCTFail("no data source")
            return
        }
        guard let collectionView = self.collectionView else {
            XCTFail("no table view")
            return
        }
        let indexPath = NSIndexPath(forRow: row, inSection: section)
        dataSource.collectionView(collectionView, didSelectItemAtIndexPath: indexPath)
    }

    func whenMovingRow(sourceRow: Int, sourceSection: Int, toRow destinationRow: Int, toSection destinationSection: Int) {
        guard let dataSource = self.dataSource else {
            XCTFail("no data source")
            return
        }
        guard let collectionView = self.collectionView else {
            XCTFail("no table view")
            return
        }
        dataSource.collectionView(collectionView, moveItemAtIndexPath: NSIndexPath(forRow: sourceRow, inSection: sourceSection), toIndexPath: NSIndexPath(forRow: destinationRow, inSection: destinationSection))
    }
    // MARK: - then

    override func thenNumberOfSectionsIs(numberOfSections: Int) {
        guard let dataSource = self.dataSource else {
            XCTFail("no data source")
            return
        }
        guard let collectionView = self.collectionView else {
            XCTFail("no collection view")
            return
        }
        XCTAssert(dataSource.numberOfSectionsInCollectionView(collectionView) == numberOfSections, "...")
    }

    // should be called thenNumberOfItemsIs(...). Any volunteers for a pull request?
    override func thenNumberOfRowsIs(numberOfRows: Int, sectionIndex: Int) {
        guard let dataSource = self.dataSource else {
            XCTFail("no data source")
            return
        }
        guard let collectionView = self.collectionView else {
            XCTFail("no collection view")
            return
        }
        XCTAssert(dataSource.collectionView(collectionView, numberOfItemsInSection: sectionIndex) == numberOfRows)
    }

    override func thenInsertionRowsSectionsAre(indexPaths: [[Int]]) {
        guard let collectionView = self.collectionView else {
            XCTFail("no table view")
            return
        }

        let realIndexPaths = indexPaths.map(testHelper_indexListMapper())

        XCTAssert(collectionView.insertionRowIndexPaths == realIndexPaths)
    }

    override func thenDeletionRowsSectionsAre(indexPaths: [[Int]]) {
        guard let collectionView = self.collectionView else {
            XCTFail("no table view")
            return
        }

        let realIndexPaths = indexPaths.map(testHelper_indexListMapper())

        XCTAssert(collectionView.deletionRowIndexPaths == realIndexPaths)
    }

    override func thenCanSelectHandlerWasCalled() {
        XCTAssert(self.didCallDidSelectHandler)
    }

    func thenCanMoveItemAtRow(row: Int, section: Int, canMove: Bool) {
        guard let dataSource = self.dataSource else {
            XCTFail("no data source")
            return
        }
        guard let collectionView = self.collectionView else {
            XCTFail("no table view")
            return
        }
        XCTAssert(dataSource.collectionView(collectionView, canMoveItemAtIndexPath: NSIndexPath(forRow: row, inSection: section)) == canMove)

    }

    // MARK: - override test
    func testDataSourceSections() {
        self.baseTestDataSourceSections()
        return
    }

    func testDataSourceRows() {
        self.baseTestDataSourceRows()
    }

    func testDataSourceRowsDelete() {
        self.baseTestDataSourceRowsDelete()
    }

    func testDataSourceWhenCompletelyEmpty() {
        self.baseTestDataSourceWhenCompletelyEmpty()
    }

    func testDidSelect() {
        self.baseTestDidSelect()
    }

    func testCanMove() {
        self.givenDelegateAndDataSource()
        self.givenCanMoveItemAtSectionID("a", rowID: "2")

        self.whenUpdatingSectionIDs(["a","b","c"])
        self.thenNumberOfSectionsIs(3)

        self.whenUpdatingRowsWithIdentifiers(["0","1","2"], sectionID: "a")
        self.thenNumberOfRowsIs(3, sectionIndex: 0)

        self.thenCanMoveItemAtRow(2, section: 0, canMove: true)
        self.thenCanMoveItemAtRow(1, section: 0, canMove: false)
    }

    func testMove() {
        self.givenDelegateAndDataSource()
        self.givenCanMoveItemAtSectionID("a", rowID: "2")
        self.givenExpectRowIDsAfterMove(["0","2","1"], forSectionID: "a", withSectionCount: 1)


        self.whenUpdatingSectionIDs(["a","b","c"])
        self.thenNumberOfSectionsIs(3)

        self.whenUpdatingRowsWithIdentifiers(["0","1","2"], sectionID: "a")
        self.thenNumberOfRowsIs(3, sectionIndex: 0)

        self.whenMovingRow(2, sourceSection: 0, toRow: 1, toSection: 0)
    }

    func testMoveBeyondLastItem() {
        self.givenDelegateAndDataSource()
        self.givenCanMoveItemAtSectionID("a", rowID: "1")
        self.givenExpectRowIDsAfterMove(["0","2","1"], forSectionID: "a", withSectionCount: 1)

        self.whenUpdatingSectionIDs(["a","b","c"])
        self.thenNumberOfSectionsIs(3)

        self.whenUpdatingRowsWithIdentifiers(["0","1","2"], sectionID: "a")
        self.thenNumberOfRowsIs(3, sectionIndex: 0)

        self.whenMovingRow(1, sourceSection: 0, toRow: 3, toSection: 0)
    }

    func testMoveAcrossSections() {
        self.givenDelegateAndDataSource()
        self.givenCanMoveItemAtSectionID("a", rowID: "3")

        self.whenUpdatingSectionIDs(["a","b","c"])

        self.whenUpdatingRowsWithIdentifiers(["0","1","2","3"], sectionID: "a")
        self.whenUpdatingRowsWithIdentifiers(["0","1","2"], sectionID: "b")

        let expectation = expectationWithDescription("sections changed callback")

        guard let dataSource = self.dataSource else {
            XCTFail()
            return
        }

        dataSource.setDidChangeSectionIDsFunc({ (inSectionIDs: Dictionary<String, Array<MockTVItem>>) -> Void in
            expectation.fulfill()
            XCTAssert(inSectionIDs.count == 2, "should be only two sections")

            guard let rowsA = inSectionIDs["a"] else {
                XCTFail("no rows for a?")
                return
            }

            let mappedIDsA = rowsA.map({ (item) -> String in
                return item.identifier
            })

            XCTAssert(mappedIDsA == ["0","1","2"])

            guard let rowsB = inSectionIDs["b"] else {
                XCTFail("no rows for b?")
                return
            }

            let mappedIDsB = rowsB.map({ (item) -> String in
                return item.identifier
            })

            XCTAssert(mappedIDsB == ["0","1","3","2"])
        })

        self.whenMovingRow(3, sourceSection: 0, toRow: 2, toSection: 1)

        self.waitForExpectationsWithTimeout(10, handler: nil)
    }

}
