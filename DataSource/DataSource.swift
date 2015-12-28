//
//  DataSource.swift
//  DBDB
//
//  Created by Ruotger Deecke on 27.07.15.
//  Copyright © 2015 Deecke,Roddi. All rights reserved.
//
// swiftlint:disable file_length

import UIKit
import FURRExtensions
import FURRDiff

enum DataSourceReportingLevel {
    case PreCondition /// always crashes
    case Assert /// crashes debug versions otherwise silent, this is the default
    case Print /// prints in debug versions otherwise silent.
    case Silent /// always silently ignores everything
}

public protocol DataItem: Equatable {
    var identifier: String { get }
}

public struct Location<T> {
    public let sectionID: String
    public let item:T
}

public struct LocationWithOptionalItem<T> {
    public let sectionID: String
    public let item: T?

    public init (sectionID  inSectionID: String, item inItem: T?) {
        self.sectionID = inSectionID
        self.item = inItem
    }
}

public class DataSource <T where T: DataItem> : NSObject, UITableViewDelegate, UITableViewDataSource {

    private let tableView: UITableView
    private let engine: DataSourceEngine<T>

    private var sectionsInternal: Array<String> = []
    private var rowsBySectionID: Dictionary<String, Array<T>> = Dictionary()

    // logging / failing
    func setFailFunc(failFunc: (String) -> Void) {
        self.engine.fail = failFunc
    }
    func setWarnFunc(warnFunc: (String) -> Void) {
        self.engine.warn = warnFunc
    }
    func setReportingLevel(level: DataSourceReportingLevel) {
        self.engine.reportingLevel = level
    }

    // trampoline methods
    public var cell: (forLocation: Location<T>) -> UITableViewCell
    public var didSelect: ((inLocation: Location<T>) -> Void)?
    public var canMove: ((toLocation: Location<T>) -> Bool)?
    public var targetMovedItem: ((fromLocation: Location<T>, proposedLocation: LocationWithOptionalItem<T>) -> LocationWithOptionalItem<T>)?
    public var canEdit: ((atLocation: Location<T>) -> Bool)?
    public var willDelete: ((atLocation: Location<T>) -> Void)?
    public var didDelete: ((item: T) -> Void)?

    public var sectionHeaderTitle: ((sectionID: String) -> String)?
    public var sectionFooterTitle: ((sectionID: String) -> String)?

    public var didChangeSectionIDs: ((inSectionIDs: Dictionary<String, Array<T>>) -> Void)?

    public init(tableView inTableView: UITableView, cellForLocationCallback inCellForLocation:(inLocation:Location<T>) -> UITableViewCell) {
        self.engine = DataSourceEngine<T>()
        self.tableView = inTableView
        self.cell = inCellForLocation

        super.init()
        self.tableView.dataSource = self
        self.tableView.delegate = self
    }

    // MARK: - querying

    public func sections() -> [String] {
        let section = self.sectionsInternal
        return section
    }

    public func rowsForSection(section: String) -> [T] {
        if let rows = self.rowsBySectionID[section] {
            return rows
        } else {
            return []
        }
    }

    public func sectionIDAndItemForIndexPath(inIndexPath: NSIndexPath) -> (String, T)? {
        let sectionIndex: Int = inIndexPath.section
        guard let (sectionID, rowArray) = self.sectionIDAndRowsForSectionIndex(sectionIndex) else {
            return nil
        }

        guard let item = rowArray.optionalElementAtIndex(inIndexPath.row) else {
            print("item not found at index \(inIndexPath.row) for sectionID \(sectionID)")
            return nil
        }

        return (sectionID, item)
    }

    // MARK: - updating

    public func updateSections(inSections: Array<String>, animated inAnimated: Bool) {

        if inSections.containsDuplicatesFast() {
            self.engine.failWithMessage("duplicate section ids - FURRDataSource will be confused by this later on so it is not permitted. Severity: lethal, sorry, nevertheless have a good evening!")
        }

        let diffs = diffBetweenArrays(arrayA: self.sectionsInternal, arrayB: inSections)

        var index = 0
        self.tableView.beginUpdates()
        for diff in diffs {
            switch diff.operation {
            case .Delete:
                for _ in diff.array {
                    self.sectionsInternal.removeAtIndex(index)
                    self.tableView.deleteSections(NSIndexSet(index: index), withRowAnimation: .Automatic)
                }
            case .Insert:
                for string in diff.array {
                    self.sectionsInternal.insert(string, atIndex: index)
                    self.tableView.insertSections(NSIndexSet(index: index), withRowAnimation: .Automatic)
                    index++
                }
            case .Equal:
                index += diff.array.count
            }
        }
        self.tableView.endUpdates()

        assert(self.sectionsInternal == inSections, "should be equal now")
    }

    public func updateRows(inRows: Array<T>, section inSectionID: String, animated inAnimated: Bool) {
        guard let sectionIndex = self.sectionIndexForSectionID(inSectionID) else {
            self.engine.warnWithMessage("sectionID does not exists. Severity: non lethal but update will fail and data source remains unaltered.")
            return
        }

        if inRows.containsDuplicates() {
            self.engine.failWithMessage("Supplied rows contain duplicates. This will confuse FURRDataSource later on. Severity: lethal, sorry.")
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

        self.tableView.beginUpdates()
        var rowIndex = 0
        var deleteRowIndex = 0
        for diff in diffs {
            switch diff.operation {
            case .Delete:
                for _ in diff.array {
                    newRows.removeAtIndex(rowIndex)
                    self.tableView.deleteRowsAtIndexPaths([NSIndexPath(forRow: deleteRowIndex, inSection: sectionIndex)], withRowAnimation: .Automatic)
                    deleteRowIndex++
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
                            self.tableView.insertRowsAtIndexPaths([NSIndexPath(forRow: rowIndex, inSection: sectionIndex)], withRowAnimation: .Automatic)
                            rowIndex++
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
        self.tableView.endUpdates()

        assert(newRows == inRows, "must be equal")
    }

    public func dequeueReusableCellWithIdentifier(identifier: String, sectionID inSectionID: String, item inItem: T) -> UITableViewCell? {
        guard let indexPath = indexPathForSectionID(inSectionID, rowItem: inItem) else {
            return nil
        }

        return self.tableView.dequeueReusableCellWithIdentifier(identifier, forIndexPath: indexPath)
    }

    public func reloadAll() {
        self.tableView.reloadData()
    }

    public func reloadSectionID(inSectionID: String) {
        if let sectionID = sectionIndexForSectionID(inSectionID) {
            self.tableView.reloadSections(NSIndexSet(index: sectionID), withRowAnimation: UITableViewRowAnimation.Automatic)
        }
    }

    public func reloadSectionID(inSectionID: String, item inItem: T) {
        if let indexPath = indexPathForSectionID(inSectionID, rowItem: inItem) {
            self.tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.Automatic)
        }
    }

    // MARK: - private

    private func indexPathForSectionID(inSectionID: String, rowItem inRowItem: T) -> NSIndexPath? {
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

    private func sectionIndexForSectionID(inSectionID: String) -> Int? {
        guard self.sectionsInternal.contains(inSectionID) else {
            return nil
        }

        return self.sectionsInternal.indexOf(inSectionID)
    }

    private func sectionIDAndRowsForSectionIndex(inSectionIndex: Int) -> (String, Array<T>)? {
        guard let sectionID = self.sectionsInternal.optionalElementAtIndex(inSectionIndex) else {
            print("section not found at index \(inSectionIndex)")
            return nil
        }

        guard let rowArray: Array<T> = self.rowsBySectionID[sectionID] else {
            print("row array not found for sectionID \(sectionID)")
            return nil
        }

        return (sectionID, rowArray)
    }

    private func locationForIndexPath(inIndexPath: NSIndexPath) -> Location<T>? {
        guard let (sectionID, item) = self.sectionIDAndItemForIndexPath(inIndexPath) else {
            return nil
        }

        let location = Location(sectionID: sectionID, item: item)
        return location
    }

    private func locationWithOptionalItemForIndexPath(inIndexPath: NSIndexPath) -> LocationWithOptionalItem<T>? {
        guard let (sectionID, rows) = self.sectionIDAndRowsForSectionIndex(inIndexPath.section) else {
            print("sectionID/row not found!")
            return nil
        }

        let item = rows.optionalElementAtIndex(inIndexPath.row)
        let location = LocationWithOptionalItem(sectionID: sectionID, item: item)

        return location
    }

    // MARK: - UITableViewDataSource

    public func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        let sections = self.sectionsInternal
        return sections.count
    }

    public func tableView(tableView: UITableView, numberOfRowsInSection inSection: Int) -> Int {
        guard let sectionID = self.sectionsInternal.optionalElementAtIndex(inSection) else {
            self.engine.failWithMessage("no section at index '\(inSection)'")
            return 0
        }

        guard let rows = self.rowsBySectionID[sectionID] else {
            // no rows for that sectionID. We don't warn as the sectionID might just be created.
            return 0
        }
        return rows.count
    }


    public func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        guard let location = self.locationForIndexPath(indexPath) else {
            preconditionFailure("rows not found")
        }

        return self.cell(forLocation: location)
    }


    public func tableView(tableView: UITableView, canMoveRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        guard let canActuallyMove = self.canMove else {
            // callback not implemented, so... no, you can't!
            return false
        }

        guard let location = self.locationForIndexPath(indexPath) else {
            return false
        }

        return canActuallyMove(toLocation: location)
    }


    public func tableView(tableView: UITableView, moveRowAtIndexPath sourceIndexPath: NSIndexPath, toIndexPath destinationIndexPath: NSIndexPath) {
        guard let (fromSectionID, fromItem) = self.sectionIDAndItemForIndexPath(sourceIndexPath) else {
            print("source not found!")
            return
        }

        var rows = self.rowsBySectionID[fromSectionID]
        rows?.removeAtIndex(sourceIndexPath.row)
        self.rowsBySectionID[fromSectionID] = rows

        guard let (toSectionID, toRows) = self.sectionIDAndRowsForSectionIndex(destinationIndexPath.section) else {
            print("destination section not found!")
            return
        }

        print("from \(fromSectionID)-\(fromItem.identifier) --- to \(toSectionID)-@\(destinationIndexPath.row)")

        rows = toRows
        if destinationIndexPath.row >= toRows.count {
            rows?.append(fromItem)
        } else {
            rows?.insert(fromItem, atIndex: destinationIndexPath.row)
        }
        self.rowsBySectionID[toSectionID] = rows

        let sectionIDs = (fromSectionID == toSectionID) ? [fromSectionID] : [fromSectionID, toSectionID]

        var changed: Dictionary<String, Array<T>> = Dictionary()
        for sectionID in sectionIDs {
            changed[sectionID] = self.rowsBySectionID[sectionID]
        }

        if let actuallyChanged = self.didChangeSectionIDs {
            // if the client bothered to implement the callback, we call it
            actuallyChanged(inSectionIDs: changed)
        }
    }

    public func tableView(tableView: UITableView, targetIndexPathForMoveFromRowAtIndexPath sourceIndexPath: NSIndexPath, toProposedIndexPath proposedDestinationIndexPath: NSIndexPath) -> NSIndexPath {
        guard let callback = self.targetMovedItem else {
            return proposedDestinationIndexPath
        }

        guard let fromLocation = self.locationForIndexPath(sourceIndexPath) else {
            print("source not found!")
            return proposedDestinationIndexPath
        }

        guard let toLocation = self.locationWithOptionalItemForIndexPath(proposedDestinationIndexPath) else {
            print("destination section not found!")
            return proposedDestinationIndexPath
        }

        // ask the our delegate where he/she wants the row
        let actualDestination = callback(fromLocation: fromLocation, proposedLocation: toLocation)

        // check whether actual destination is OK
        if let item = actualDestination.item, let indexPath = indexPathForSectionID(actualDestination.sectionID, rowItem: item) {
            return indexPath
        }

        guard let sectionIndex = self.sectionIndexForSectionID(actualDestination.sectionID) else {
            print("actual destination section not found!")
            return proposedDestinationIndexPath
        }

        if let rows = self.rowsBySectionID[actualDestination.sectionID] {
            return NSIndexPath(forRow: rows.count-1, inSection: sectionIndex)
        } else {
            print("actual destination section not found!")
            return proposedDestinationIndexPath
        }
    }

    public func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {

        switch editingStyle {
        case .Delete:
            guard let location = self.locationForIndexPath(indexPath) else {
                return
            }

            if let callback = self.willDelete {
                callback(atLocation: location)
            }

            if var rows = self.rowsBySectionID[location.sectionID] {
                rows.removeAtIndex(indexPath.row)
                self.updateRows(rows, section: location.sectionID, animated: true)
            }

            if let callback = self.didDelete {
                callback(item: location.item)
            }

            if let callback = self.didChangeSectionIDs {
                let sectionID = location.sectionID
                let rows = self.rowsBySectionID[sectionID]
                if let rows_ = rows {
                    callback(inSectionIDs: [sectionID:rows_])
                }
            }

        case .Insert:
            print(".Insert ????")

        case .None:
            print(".None ????")
        }
    }

    public func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        guard let location = self.locationForIndexPath(indexPath) else {
            return false
        }

        guard let callback = self.canEdit else {
            return false
        }

        return callback(atLocation: location)
    }

    public func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let sectionID = self.sectionsInternal.optionalElementAtIndex(section) else {
            self.engine.warnWithMessage("section not found at index \(section)")
            return nil
        }

        guard let callback = self.sectionHeaderTitle else {
            return nil
        }

        return callback(sectionID: sectionID)

    }

    public func tableView(tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard let sectionID = self.sectionsInternal.optionalElementAtIndex(section) else {
            self.engine.warnWithMessage("section not found at index \(section)")
            return nil
        }

        guard let callback = self.sectionFooterTitle else {
            return nil
        }

        return callback(sectionID: sectionID)
    }


}


    // MARK: - UITableViewDelegate

extension DataSource {
    public func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        guard let callback = self.didSelect else {
            return
        }

        guard let location = self.locationForIndexPath(indexPath) else {
            return
        }

        callback(inLocation: location)
    }
}

// swiftlint:enable file_length
