//
//  Schedule.swift
//  MAMONAKU
//
//  Created by ryota.saito on 2026/01/19.
//

import Foundation

struct TimelineItem: Identifiable, Equatable, Codable {
    let id: UUID
    let title: String
    var durationMinutes: Int
    var startMinutes: Int?
    var dropDate: Date?

    init(
        id: UUID = UUID(),
        title: String,
        durationMinutes: Int,
        startMinutes: Int? = nil,
        dropDate: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.durationMinutes = durationMinutes
        self.startMinutes = startMinutes
        self.dropDate = dropDate
    }
}
