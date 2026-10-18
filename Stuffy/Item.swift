//
//  Item.swift
//  Stuffy
//
//  Created by Hao on 10/17/26.
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
