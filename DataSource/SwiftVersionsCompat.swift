//
//  SwiftVersionsCompat.swift
//  FURRDataSource
//
//  Created by Ruotger Deecke on 05.07.16.
//  Copyright © 2016 Ruotger Deecke. All rights reserved.
//

import UIKit

enum CompatTableViewCellEditingStyle {
    case delete
    case insert
    case none
}

enum CompatTableViewCellStyle {
    case `default`
    case value1
    case value2
    case subtitle
}

enum CompatUITableViewStyle {
    case plain          // regular table view
    case grouped         // preferences style table view
}

#if swift(>=3.0)
    public typealias IndexPathway = IndexPath

    extension CompatTableViewCellEditingStyle {
        init(editingStyle: UITableViewCellEditingStyle) {
            switch editingStyle {
            case .delete:
                self = .delete
            case .insert:
                self = .insert
            case .none:
                self = .none
            }
        }
    }

    extension CompatTableViewCellStyle {
        func uiStyle() -> UITableViewCellStyle {
            switch self {
            case .default:
                return UITableViewCellStyle.default
            case .value1:
                return UITableViewCellStyle.value1
            case .value2:
                return UITableViewCellStyle.value2
            case .subtitle:
                return UITableViewCellStyle.subtitle
            }
        }
    }

    extension CompatUITableViewStyle {
        func uiStyle() -> UITableViewStyle {
            switch self {
            case .grouped:
                return UITableViewStyle.grouped
            case .plain:
                return UITableViewStyle.plain
            }
        }
    }

#else
    public typealias IndexPathway = NSIndexPath

    extension CompatTableViewCellEditingStyle {
    init(editingStyle: UITableViewCellEditingStyle) {
    switch editingStyle {
    case .Delete:
    self = .delete
    case .Insert:
    self = .insert
    case .None:
    self = .none
    }
    }
    }

    extension CompatTableViewCellStyle {
    func uiStyle() -> UITableViewCellStyle {
    switch self {
    case `default`:
    return UITableViewCellStyle.Default
    case value1:
    return UITableViewCellStyle.Value1
    case value2:
    return UITableViewCellStyle.Value2
    case subtitle:
    return UITableViewCellStyle.Subtitle
    }
    }
    }

    extension CompatUITableViewStyle {
    func uiStyle() -> UITableViewStyle {
    switch self {
    case .grouped:
    return UITableViewStyle.grouped
    case .plain:
    return UITableViewStyle.plain
    }
    }
    }

#endif
