//
//  ErrorView.swift
//  Fuzy
//
//  Created by Luka Alimbarashvili on 10/11/2026.
//

import SwiftUI

struct ErrorView: View {
    let message: String
    let action: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Couldn't load prices", systemImage: "wifi.exclamationmark")
        } description: {
            Text(message)
        } actions: {
            Button("Retry") { action() }
        }
    }
}
