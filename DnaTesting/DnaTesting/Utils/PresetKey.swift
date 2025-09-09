import Foundation
import CryptoKit
import DnaCommunicator

struct PresetKey: Hashable {
	let keySet: KeySet
	let name: String
	
	static var alice: PresetKey {
		return PresetKey(keySet: KeySet(key0Hex: "01234567890abcdef01234567890abcd")!, name: "Alice")
	}
	
	static var bob: PresetKey {
		return PresetKey(keySet: KeySet(key0Hex: "b8c9e9b95b3763b47eee4566e4b8bea8")!, name: "Bob")
	}
	
	static var carol: PresetKey {
		return PresetKey(keySet: KeySet(key0Hex: "ae9beccb057df18d60fd8cde58a1d6ec")!, name: "Carol")
	}
	
	static var count: Int {
		return all().count
	}
	
	static func all() -> [PresetKey] {
		return [
			PresetKey.alice,
			PresetKey.bob,
			PresetKey.carol
		]
	}
}

struct KeySet: Hashable {
	let key0: Data
	
	static let KEY_SIZE = 16 // 16 bytes == 128 bits
	
	init(key0: Data) {
		precondition(key0.count == Self.KEY_SIZE, "Invalid key size")
		self.key0 = key0
	}
	
	init?(key0Hex: String) {
		if let data = Data(fromHex: key0Hex) {
			self.init(key0: data)
		} else {
			return nil
		}
	}
	
	var piccDataKey: Data {
		keyGen("piccDataKey")
	}

	var cmacKey: Data {
		keyGen("cmacKey")
	}
	
	private func keyGen(_ keyId: String) -> Data {
		let inner = sha256Hash(key0)
		let outer = sha256Hash(keyId.data(using: .utf8)!)
		
		let hashMe = outer + inner + outer
		return sha256Hash(hashMe).prefix(Self.KEY_SIZE)
	}

	private func sha256Hash(_ data: Data) -> Data {
		let result: SHA256Digest = SHA256.hash(data: data)
		return result.dataRepresentation
	}
}

extension ContiguousBytes {
	
	var dataRepresentation: Data {
		return self.withUnsafeBytes { bytes in
			Data(bytes: bytes.baseAddress!, count: bytes.count)
		}
	}
}
