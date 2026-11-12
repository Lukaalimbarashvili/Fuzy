//
//  WatchItem.swift
//  Fuzy
//
//  Created by Luka Alimbarashvili on 10/11/2026.
//

import Foundation

struct WatchItem: Identifiable {
    var id: String { symbol }
    var symbol: String
    var description: String
    var price: Double
    var changePercent: Double?
}
