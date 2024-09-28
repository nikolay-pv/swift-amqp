// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import Mustache

let specFile = FileManager.default.currentDirectoryPath.appending("/amqp-rabbitmq-0.9.1.json")
let data = FileManager.default.contents(atPath: specFile)
guard let data else {
    fatalError("Can't get the content of \(specFile)")
}
let specDict = try JSONDecoder().decode(AMQPSpec.self, from: data)


let template = try Template(named: "spec_template", bundle: Bundle.module)

// inject
let input = [String: Any]()

let rendered = try template.render(input)
let outputFile = FileManager.default.currentDirectoryPath.appending("/test.swift")
FileManager.default.createFile(atPath: outputFile, contents: rendered.data(using: .utf8))


