//
//  ErrorView.swift
//  Fuzy
//
//  Created by Luka Alimbarashvili on 11/11/2026.
//

import SwiftUI

struct ErrorView: View {

    let message: String
    let action: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Something went wrong”", systemImage: "wifi.exclamationmark")
        } description: {
            Text(message)
        } actions: {
            Button("Retry") {
                action()
            }
        }
    }
}
