//
//  ViewState.swift
//  Fuzy
//
//  Created by Luka Alimbarashvili on 10/11/2026.
//

enum ViewState<Value> {
    case loading
    case loaded(Value)
    case error(String)
}
