//
//  WatchRow.swift
//  Fuzy
//
//  Created by Luka Alimbarashvili on 10/11/2026.
//

import SwiftUI

struct WatchRow: View {
    
    @State var watchItem: WatchItem
    
    var body: some View {
        HStack(spacing: 12) {
            logo(instrument: watchItem.symbol)
            
            VStack(alignment: .leading) {
                Text(watchItem.symbol)
                Text(watchItem.description)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text(watchItem.price.formatted(.currency(code: "USD")))
                Text(changeText)
                    .foregroundStyle(changeColor)
            }
            
        }
    }
    
    private var changeText: String {
        guard let value = watchItem.changePercent else { return "—" }
        return String(format: "%+.2f%%", value)
    }

    private var changeColor: Color {
        guard let value = watchItem.changePercent else { return .secondary }
        return value >= 0 ? .green : .red
    }

    private func logo(instrument: String) -> some View {
        ZStack {
            Circle()
                .fill(.blue.opacity(0.2))
            Text(String(instrument.prefix(1)))
        }
        .frame(width: 40, height: 40)
    }
}
