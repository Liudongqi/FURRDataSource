// swiftlint:disable function_body_length
// swiftlint:disable line_length
// swiftlint:disable cyclomatic_complexity
//
//  DataSourceEngine.swift
//  FURRDataSource
//
//  Created by Ruotger Deecke on 26.12.15.
//  Copyright © 2015-2016 Ruotger Deecke. All rights reserved.
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

import Foundation
import FURRDiff

public enum DataSourceReportingLevel {
    case PreCondition /// always crashes
    case Assert /// crashes debug versions otherwise silent, this is the default
    case Print /// prints in debug versions otherwise silent.
    case Verbose /// prints a lot of stuff.
    case Silent /// always silently ignores everything
}

internal class DataSourceEngine <T where T: DataItem> {
    private var sectionsInternal: Array<String> = []
    private var rowsBySectionID: Dictionary<String, Array<T>> = Dictionary()

    internal var reportingLevel: DataSourceReportingLevel = .Assert

    // MARK: - delegate blocks
    var beginUpdates: (() -> Void)?
    var endUpdates: (() -> Void)?

    var deleteSections: ((NSIndexSet) -> Void)?
    var insertSections: ((NSIndexSet) -> Void)?

    var deleteRowsAtIndexPaths: (([NSIndexPath]) -> Void)?
    var insertRowsAtIndexPaths: (([NSIndexPath]) -> Void)?

    var didChangeSectionIDs: ((inSectionIDs: Dictionary<String, Array<T>>) -> Void)?

    internal var fail: ((String) -> Void )?
    internal var warn: ((String) -> Void )?

    // MARK: - querying

    // MARK: by id

    func sections() -> [String] {
        let sections = self.sectionsInternal
        return sections
    }

    func rowsForSection(section: String) -> [T] {
        if let rows = self.rowsBySectionID[section] {
            return rows
        } else {
            return []
        }
    }

    // MARK: by index

    func numberOfRowsForSectionIndex(index: Int) -> Int {
        guard let sectionID = self.sections().optionalElement(index) else {
            self.failWithMessage("no section at index '\(index)'")
            return 0
        }

        let rows = self.rowsForSection(sectionID)
        return rows.count
    }

    func sectionIDAndItemForIndexPath(inIndexPath: NSIndexPath) -> (String, T)? {
        let sectionIndex: Int = inIndexPath.section
        guard let (sectionID, rowArray) = self.sectionIDAndRowsForSectionIndex(sectionIndex) else {
            return nil
        }

        guard let item = rowArray.optionalElement(inIndexPath.row) else {
            print("item not found at index \(inIndexPath.row) for sectionID \(sectionID)")
            return nil
        }

        return (sectionID, item)
    }

    func sectionIDAndRowsForSectionIndex(inSectionIndex: Int) -> (String, Array<T>)? {
        guard let sectionID = self.sectionsInternal.optionalElement(inSectionIndex) else {
            print("section not found at index \(inSectionIndex)")
            return nil
        }

        guard let rowArray: Array<T> = self.rowsBySectionID[sectionID] else {
            print("row array not found for sectionID \(sectionID)")
            return nil
        }

        return (sectionID, rowArray)
    }

    // MARK: - updating
    func updateSections(inSections: Array<String>, animated inAnimated: Bool) {

        if inSections.containsDuplicatesFast() {
            self.failWithMessage("duplicate section ids - FURRDataSource will be confused by this later on so it is not permitted. Severity: lethal, sorry, nevertheless have a good evening!")
            return
        }

        guard
            let beginUpdatesFunc = self.beginUpdates,
            endUpdatesFunc = self.endUpdates,
            deleteSectionsFunc = self.deleteSections,
            insertSectionsFunc = self.insertSections else {
                self.failWithMessage("At least one of the required callback funcs of DataSourceEngine is nil. Severity: lethal, sorry, nevertheless have a good evening!")
                return
        }

        let diffs = diffBetweenArrays(arrayA: self.sectionsInternal, arrayB: inSections)

        var index = 0
        beginUpdatesFunc()
        for diff in diffs {
            switch diff.operation {
            case .Delete:
                for _ in diff.array {
                    self.sectionsInternal.removeAtIndex(index)
                    deleteSectionsFunc(NSIndexSet(index: index))
                }
            case .Insert:
                for string in diff.array {
                    self.sectionsInternal.insert(string, atIndex: index)
                    insertSectionsFunc(NSIndexSet(index: index))
                    index += 1
                }
            case .Equal:
                index += diff.array.count
            }
        }
        endUpdatesFunc()

        assert(self.sectionsInternal == inSections, "should be equal now")
    }

    func updateRows(inRows: Array<T>, section inSectionID: String, animated inAnimated: Bool) {
        guard let sectionIndex = self.sectionIndexForSectionID(inSectionID) else {
            self.warnWithMessage("sectionID does not exists. Severity: non lethal but update will fail and data source remains unaltered.")
            return
        }

        if inRows.containsDuplicates() {
            self.failWithMessage("Supplied rows contain duplicates. This will confuse FURRDataSource later on. Severity: lethal, sorry.")
            return
        }

        guard
            let beginUpdatesFunc = self.beginUpdates,
            endUpdatesFunc = self.endUpdates,
            deleteRowsAtIndexPathsFunc = self.deleteRowsAtIndexPaths,
            insertRowsAtIndexPathsFunc = self.insertRowsAtIndexPaths else {
                self.failWithMessage("At least one of the required callback funcs of DataSourceEngine is nil. Severity: lethal, sorry, nevertheless have a good evening!")
                return
        }

        let existingRows: [T]
        if let exRows = self.rowsBySectionID[inSectionID] {
            existingRows = exRows
        } else {
            existingRows = []
        }

        var newRows: Array<T> = existingRows

        let newIdentifiers = inRows.map({ (inDataSourceItem) -> String in
            return inDataSourceItem.identifier
        })
        let existingIdentifiers = existingRows.map({ (inDataSourceItem) -> String in
            return inDataSourceItem.identifier
        })

        let diffs = diffBetweenArrays(arrayA: existingIdentifiers, arrayB: newIdentifiers)

        beginUpdatesFunc()
        var rowIndex = 0
        var deleteRowIndex = 0
        for diff in diffs {
            switch diff.operation {
            case .Delete:
                for _ in diff.array {
                    newRows.removeAtIndex(rowIndex)
                    deleteRowsAtIndexPathsFunc([NSIndexPath(forRow: deleteRowIndex, inSection: sectionIndex)])
                    deleteRowIndex += 1
                }
            case .Insert:
                for rowID in diff.array {
                    // find index of new row
                    let rowIDIndex = inRows.indexOf({ (inDataSourceItem) -> Bool in
                        return rowID == inDataSourceItem.identifier
                    })

                    if let actualIndex = rowIDIndex {
                        let newRow = inRows[actualIndex]
                        newRows.insert(newRow, atIndex: rowIndex)
                        insertRowsAtIndexPathsFunc([NSIndexPath(forRow: rowIndex, inSection: sectionIndex)])
                        rowIndex += 1
                    } else {
                        print("index not found for rowID '\(rowID)'")
                    }
                }

            case .Equal:
                rowIndex += diff.array.count
                deleteRowIndex += diff.array.count
            }
        }
        self.rowsBySectionID[inSectionID] = newRows
        endUpdatesFunc()

        assert(newRows == inRows, "must be equal")
    }

    // MARK: - initiated by user

    func moveRowAtIndexPath( sourceIndexPath: NSIndexPath, toIndexPath destinationIndexPath: NSIndexPath) {
        guard let (fromSectionID, fromItem) = self.sectionIDAndItemForIndexPath(sourceIndexPath) else {
            print("source not found!")
            return
        }

        guard let didChangeSectionIDsFunc = self.didChangeSectionIDs else {
            self.failWithMessage("At least one of the required callback funcs of DataSourceEngine is nil. Severity: lethal, sorry, nevertheless have a good evening!")
            return
        }

        var rows = self.rowsForSection(fromSectionID)
        rows.removeAtIndex(sourceIndexPath.row)
        self.rowsBySectionID[fromSectionID] = rows

        guard let (toSectionID, toRows) = self.sectionIDAndRowsForSectionIndex(destinationIndexPath.section) else {
            print("destination section not found!")
            return
        }

        print("from \(fromSectionID)-\(fromItem.identifier) --- to \(toSectionID)-@\(destinationIndexPath.row)")

        rows = toRows
        if destinationIndexPath.row >= toRows.count {
            rows.append(fromItem)
        } else {
            rows.insert(fromItem, atIndex: destinationIndexPath.row)
        }
        self.rowsBySectionID[toSectionID] = rows

        let sectionIDs = (fromSectionID == toSectionID) ? [fromSectionID] : [fromSectionID, toSectionID]

        var changed: Dictionary<String, Array<T>> = Dictionary()
        for sectionID in sectionIDs {
            changed[sectionID] = self.rowsBySectionID[sectionID]
        }

        didChangeSectionIDsFunc(inSectionIDs: changed)
    }

    // MARK: - private

    func indexPathForSectionID(inSectionID: String, rowItem inRowItem: T) -> NSIndexPath? {
        guard let sectionIndex = sectionIndexForSectionID(inSectionID) else {
            return nil
        }

        guard let rows: Array<T> = self.rowsBySectionID[inSectionID] else {
            return nil
        }

        guard let rowIndex = rows.indexOf(inRowItem) else {
            return nil
        }

        return NSIndexPath(forRow: rowIndex, inSection: sectionIndex)
    }

    func sectionIndexForSectionID(inSectionID: String) -> Int? {
        guard self.sectionsInternal.contains(inSectionID) else {
            return nil
        }

        return self.sectionsInternal.indexOf(inSectionID)
    }


    func locationForIndexPath(inIndexPath: NSIndexPath) -> Location<T>? {
        guard let (sectionID, item) = self.sectionIDAndItemForIndexPath(inIndexPath) else {
            return nil
        }

        let location = Location(sectionID: sectionID, item: item)
        return location
    }

    func locationWithOptionalItemForIndexPath(inIndexPath: NSIndexPath) -> LocationWithOptionalItem<T>? {
        guard let (sectionID, rows) = self.sectionIDAndRowsForSectionIndex(inIndexPath.section) else {
            print("sectionID/row not found!")
            return nil
        }

        let item = rows.optionalElement(inIndexPath.row)
        let location = LocationWithOptionalItem(sectionID: sectionID, item: item)

        return location
    }

    // MARK: - handling errors

    func reportWarningAccordingToLevel(message: String) {
        switch self.reportingLevel {
            // a warning will still trigger an assertion.
        case .PreCondition:
            preconditionFailure("ERROR: \(message)")

        case .Assert:
            assertionFailure("WARNING: \(message)")
        case .Print, .Verbose:
            print("WARNING: \(message)")
        case .Silent:
            // nothing to do here
            break
        }
    }

    func failWithMessage(message: String) {
        // when there's a fail block, we fail into that block otherwise
        // we fail according to the reporting level
        if let failBlock = self.fail {
            failBlock(message)
            return
        }

        preconditionFailure("FATAL ERROR: \(message)")
    }

    func warnWithMessage(message: String) {
        // when there's a fail block, we fail into that block otherwise
        // we fail according to the reporting level
        if let warnBlock = self.warn {
            warnBlock(message)
            return
        }

        self.reportWarningAccordingToLevel(message)
    }

    func logWhenVerbose(@autoclosure message: () -> String) {
        if self.reportingLevel == .Verbose {
            print(message)
        }
    }

}
