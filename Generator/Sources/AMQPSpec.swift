//
//  AMQPEntities.swift
//  
//
//  Created by Nikolay Petrov on 13.07.2024.
//

struct AMQPSpec: Decodable {
    var name: String
    var copyright: [String]
    var majorVersion: Int
    var minorVersion: Int
    var revision: Int
    var port: Int
    var domains: [AMQPDomain]
    var constants: [AMQPConstant]
    var classes: [AMQPClass]

    enum CodingKeys: String, CodingKey {
        case name
        case copyright
        case majorVersion = "major-version"
        case minorVersion = "minor-version"
        case revision
        case port
        case domains
        case constants
        case classes
    }

    struct AMQPDomain: Decodable {
        var domain: String
        var type: String

        init(from decoder: Decoder) throws {
            var values = try decoder.unkeyedContainer()
            precondition(values.count == 2)
            self.domain = try values.decode(String.self)
            self.type = try values.decode(String.self)
        }
    }

    struct AMQPConstant: Decodable {
        var name: String
        var value: Int
        var cls: String?
    }

    struct AMQPProperty: Decodable {
        var type: String
        var name: String
    }

    struct AMQPClass: Decodable {
        var id: Int
        var name: String
        var methods: [AMQPMethod]
        var propertis: [AMQPProperty]?
    }

    struct AMQPMethod: Decodable {
        var id: Int
        var name: String
        var arguments: [AMQPField]
        var synchronous: Bool?
    }

    struct AMQPField: Decodable {
        var type: String?
        var domain: String?
        var name: String
        var defaultValue: DefaultUnion?

        enum CodingKeys: String, CodingKey {
            case type
            case domain
            case name
            case defaultValue = "default-value"
        }

        func realType(spec: borrowing AMQPSpec) -> String {
            if let type {
                return type
            } else if let domain {
                guard let domainDef = spec.domains.first(where: { $0.domain == domain }) else {
                    fatalError("Domain \(domain) is not specified in the AMQP spec")
                }
                return domainDef.type
            }
            fatalError("Type or domain must be specified for a field")
        }

        enum DefaultUnion {
            case string(String), boolean(Bool), integer(Int), emptyObject
        }

        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            self.type = try values.decodeIfPresent(String.self, forKey: CodingKeys.type)
            self.domain = try values.decodeIfPresent(String.self, forKey: CodingKeys.domain)
            self.name = try values.decode(String.self, forKey: CodingKeys.name)
            // All possible unique default-values
            //
            // {"type": "bit", "default-value": false}
            // {"type": "bit", "default-value": true}
            //
            // {"type": "long", "default-value": 0}
            // {"type": "longlong", "default-value": 0}
            // {"type": "octet", "default-value": 0}
            // {"type": "octet", "default-value": 9}
            // {"type": "short", "default-value": 0}
            // {"type": "short", "default-value": 1}
            // {"domain": "short", "default-value": 0}
            //
            // {"type": "table", "default-value": {}}
            //
            // {"domain": "exchange-name", "default-value": ""}
            // {"domain": "queue-name", "default-value": ""}
            //
            // {"type": "longstr", "default-value": ""}
            // {"type": "longstr", "default-value": "PLAIN"}
            // {"type": "longstr", "default-value": "en_US"}
            // {"type": "shortstr", "default-value": ""}
            // {"type": "shortstr", "default-value": "/"}
            // {"type": "shortstr", "default-value": "/data"}
            // {"type": "shortstr", "default-value": "PLAIN"}
            // {"type": "shortstr", "default-value": "direct"}
            // {"type": "shortstr", "default-value": "en_US"}

            // type and domain can't be specified together
            precondition(self.type == nil || self.domain == nil)
            let typeOrDomain = self.type ?? self.domain!

            if !values.allKeys.contains(CodingKeys.defaultValue) {
                self.defaultValue = nil
                return
            }
            switch typeOrDomain {
            case "shortstr", "longstr", "exchange-name", "queue-name":
                let def = try values.decode(String.self, forKey: CodingKeys.defaultValue)
                self.defaultValue = .string(def)
            case "table":
                let def = try values.decode(Dictionary<Int, Int>.self, forKey: CodingKeys.defaultValue)
                precondition(def.isEmpty, "Can't handle a non empty dictionary for table type as default value")
                self.defaultValue = .emptyObject
            case "bit":
                let def = try values.decode(Bool.self, forKey: CodingKeys.defaultValue)
                self.defaultValue = .boolean(def)
            case "long", "longlong", "octet", "short":
                let def = try values.decode(Int.self, forKey: CodingKeys.defaultValue)
                self.defaultValue = .integer(def)
            default:
                fatalError("Can't decode default value for \(typeOrDomain)")
            }
        }
    }
}
