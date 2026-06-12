//
//  SDUIScreen.swift
//  sdui
//
//  A decoded screen definition: an id, an optional navigation title, and the
//  root component of the recursive tree.
//

struct SDUIScreen: Decodable {
    let id: String
    var title: String?
    let root: SDUIComponent
}
