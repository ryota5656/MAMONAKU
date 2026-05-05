//
//  Schedule.swift
//  MAMONAKU
//
//  Created by ryota.saito on 2026/01/19.
//

import Foundation

enum TaskPriority: Int, CaseIterable, Codable, Equatable {
    case low = 0
    case medium = 1
    case high = 2

    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }

    var iconName: String {
        switch self {
        case .low: return "minus"
        case .medium: return "chevron.up"
        case .high: return "chevron.up.2"
        }
    }
}

struct TimelineItem: Identifiable, Equatable, Codable {
    let id: UUID
    let title: String
    var durationMinutes: Int
    var startMinutes: Int?
    var dropDate: Date?
    var isCompleted: Bool
    var priority: TaskPriority
    var isAllDay: Bool
    /// 将来的なタスク個別バッファ分（現状は全体設定が優先）
    var bufferMinutes: Int?

    init(
        id: UUID = UUID(),
        title: String,
        durationMinutes: Int,
        startMinutes: Int? = nil,
        dropDate: Date? = nil,
        isCompleted: Bool = false,
        priority: TaskPriority = .medium,
        isAllDay: Bool = false,
        bufferMinutes: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.durationMinutes = durationMinutes
        self.startMinutes = startMinutes
        self.dropDate = dropDate
        self.isCompleted = isCompleted
        self.priority = priority
        self.isAllDay = isAllDay
        self.bufferMinutes = bufferMinutes
    }
}
