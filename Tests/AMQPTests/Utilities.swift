//
//  Utilities.swift
//  swift-amqp
//
//  Created by Nikolay Petrov on 31.10.2024.
//

import Foundation

func fixtureData(for fixture: String) throws -> Data {
    try Data(contentsOf: fixtureUrl(for: fixture))
}


func fixtureUrl(for fixture: String) -> URL {
    fixturesDirectory().appendingPathComponent(fixture)
}


func fixturesDirectory(path: String = #filePath) -> URL {
    let url = URL(fileURLWithPath: path)
    let testsDir = url.deletingLastPathComponent()
    let res = testsDir.appendingPathComponent("Resources").appendingPathComponent("Fixtures")
    return res
}
