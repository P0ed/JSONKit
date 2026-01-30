import Foundation

public struct JSON {
	public var object: Any
	public var codingPath: [CodingKey]
}

public extension JSON {

	enum Key {
		case field(String)
		case index(Int)
	}

	init(_ object: Any) { self = JSON(object: object, codingPath: []) }

	subscript(_ field: String) -> JSON { get throws { try nestedContainer(.field(field)) } }
	subscript(_ index: Int) -> JSON { get throws { try nestedContainer(.index(index)) } }

	func nestedContainer(_ key: Key) throws -> JSON {
		let nestedObject: Any? = try {
			switch key {
			case .index(let idx):
				let array = try convert(NSArray.self)
				return idx < array.count ? array[idx] : nil
			case .field(let field):
				return try convert(NSDictionary.self)[field]
			}
		}()

		if let object = nestedObject {
			return JSON(object: object, codingPath: codingPath + [key])
		} else {
			throw DecodingError.keyNotFound(key, .path(codingPath))
		}
	}
	func array() throws -> [JSON] {
		try convert(NSArray.self).enumerated().map { JSON(object: $1, codingPath: codingPath + [Key.index($0)]) }
	}
	func decode<A>(_ transform: (JSON) throws -> A) throws -> A {
		try decodeOptional(transform)
			?? { throw DecodingError.valueNotFound(A.self, .path(codingPath)) }()
	}
	func decodeOptional<A>(_ transform: (JSON) throws -> A) throws -> A? {
		object is NSNull ? nil : try transform(self)
	}
	func convert<A>(_ type: A.Type = A.self) throws -> A {
		try decode { json in try (json.object as? A)
			?? { throw DecodingError.typeMismatch(A.self, .path(json.codingPath)) }()
		}
	}
	func decode<A: JSONDecodable>(_ type: A.Type = A.self) throws -> A { try decode(A.init(json:)) }
	func decodeOptional<A: JSONDecodable>(_ type: A.Type = A.self) throws -> A? { try decodeOptional(A.init(json:)) }
}

extension JSON.Key: CodingKey {
	public var stringValue: String {
		switch self {
		case .field(let value): value
		case .index(let value): "\(value)"
		}
	}
	public var intValue: Int? {
		switch self {
		case .field: nil
		case .index(let value): value
		}
	}
	public init?(stringValue: String) { self = .field(stringValue) }
	public init?(intValue: Int) { self = .index(intValue) }
}

public protocol JSONDecodable {
	init(json: JSON) throws
}

extension Array: JSONDecodable where Element: JSONDecodable {
	public init(json: JSON) throws { self = try json.array().map { try $0.decode() } }
}

// MARK: Types convertible from `Any` with `as?` operator
public protocol JSONConvertible: JSONDecodable {}

public extension JSONConvertible {
	init(json: JSON) throws { self = try json.convert() }
}

extension NSDictionary: JSONConvertible {}
extension NSArray: JSONConvertible {}
extension NSNumber: JSONConvertible {}
extension String: JSONConvertible {}
extension Int: JSONConvertible {}
extension Int8: JSONConvertible {}
extension Int16: JSONConvertible {}
extension Int32: JSONConvertible {}
extension Int64: JSONConvertible {}
extension UInt: JSONConvertible {}
extension UInt8: JSONConvertible {}
extension UInt16: JSONConvertible {}
extension UInt32: JSONConvertible {}
extension UInt64: JSONConvertible {}
extension Float: JSONConvertible {}
extension Double: JSONConvertible {}
extension Bool: JSONConvertible {}

private extension DecodingError.Context {
	static func path(_ codingPath: [CodingKey]) -> DecodingError.Context {
		DecodingError.Context(
			codingPath: codingPath,
			debugDescription: codingPath.map { $0.stringValue }.debugDescription
		)
	}
}

public extension JSON {
	init(data: Data, options: JSONSerialization.ReadingOptions = []) throws {
		self = JSON(try JSONSerialization.jsonObject(with: data, options: options))
	}
	init(string: String) throws {
		self = try JSON(
			data: string.data(using: .utf8) ?? {
				throw DecodingError.dataCorrupted(DecodingError.Context(
					codingPath: [], debugDescription: "Can't form utf8 data from string"
				))
			}()
		)
	}
}

extension URL: JSONDecodable {
	public init(json: JSON) throws {
		let string = try json.decode() as String
		guard let encodedString = string.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
			throw DecodingError.dataCorrupted(DecodingError.Context(
				codingPath: json.codingPath,
				debugDescription: "Failed percent encoding"
			))
		}
		guard let url = URL(string: encodedString) else {
			throw DecodingError.dataCorrupted(DecodingError.Context(
				codingPath: json.codingPath,
				debugDescription: "URL is malformed"
			))
		}
		self = url
	}
}
