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
            logo(instrument: watchItem.instrument)
            
            VStack(alignment: .leading) {
                Text(watchItem.instrument)
                Text(watchItem.desciption)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text(String(watchItem.price))
                Text(String(watchItem.change))
                    .foregroundStyle(.red)
            }
            
        }
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
