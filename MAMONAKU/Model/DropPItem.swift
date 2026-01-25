//
//  DropPreview.swift
//  MAMONAKU
//
//  Created by ryota.saito on 2026/01/19.
//

import Foundation

struct DropPreview: Identifiable, Equatable {
    let id = UUID()
    let title: String
    var startMinutes: Int
    var durationMinutes: Int
}
