//
//  ChipItem.swift
//  MAMONAKU
//
//  Created by ryota.saito on 2026/01/19.
//

struct ChipItemData: Identifiable {
    enum Kind {
        case duration(Int)
        case quickAdd
    }

    let id: String
    let title: String
    let kind: Kind
}
