//
//  SDUIScreenLoader.swift
//  sdui
//
//  How a screen definition is fetched. `BundleScreenLoader` reads bundled JSON;
//  swap in a remote loader (same protocol) to drive screens from a server with
//  no renderer changes.
//

import Foundation

protocol SDUIScreenLoader {
    func load(id: String) throws -> SDUIScreen
}

struct BundleScreenLoader: SDUIScreenLoader {
    enum LoaderError: LocalizedError {
        case notFound(String)
        var errorDescription: String? {
            switch self {
            case .notFound(let id): "No bundled screen named “\(id).json”."
            }
        }
    }

    let bundle: Bundle

    init(bundle: Bundle = .main) { self.bundle = bundle }

    func load(id: String) throws -> SDUIScreen {
        guard let url = bundle.url(forResource: id, withExtension: "json") else {
            throw LoaderError.notFound(id)
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(SDUIScreen.self, from: data)
    }
}
