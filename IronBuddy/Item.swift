//
//  Item.swift
//  IronBuddy
//
//  Created by Peishen Li on 2026/3/31.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
