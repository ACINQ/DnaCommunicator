import Foundation

extension Utils {
	
	static let zeroIV: [UInt8] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
	
	static func simpleAesEncrypt(key: [UInt8], data: [UInt8], iv: [UInt8] = zeroIV) -> [UInt8] {
		
		guard MiniSwCrypt.CC.available() else {
			assertionFailure("MiniSwCrypt.CC.available() == false")
			return [UInt8]()
		}
		
		let _key: Data = key.toData()
		let _data: Data = data.toData()
		let _iv: Data = iv.toData()
		
		do {
			let result = try MiniSwCrypt.CC.crypt(
				.encrypt,
				blockMode : .cbc,
				algorithm : .aes,
				padding   : .noPadding,
				data      : _data,
				key       : _key,
				iv        : _iv
			)
			return result.toByteArray()

		} catch {
			assertionFailure("MiniSwCrypt.CC.crypt(): error: \(error)")
			return [UInt8]()
		}
	}
	
	static func simpleAesDecrypt(key: [UInt8], data: [UInt8], iv: [UInt8] = zeroIV) -> [UInt8] {
		
		guard MiniSwCrypt.CC.available() else {
			assertionFailure("MiniSwCrypt.CC.available() == false")
			return [UInt8]()
		}
		
		let _key: Data = key.toData()
		let _data: Data = data.toData()
		let _iv: Data = iv.toData()
		 
		do {
			let result = try MiniSwCrypt.CC.crypt(
				.decrypt,
				blockMode : .cbc,
				algorithm : .aes,
				padding   : .noPadding,
				data      : _data,
				key       : _key,
				iv        : _iv
			)
			return result.toByteArray()

		} catch {
			assertionFailure("MiniSwCrypt.CC.crypt(): error: \(error)")
			return [UInt8]()
		}
	}
	
	static func simpleCMAC(key: [UInt8], data: [UInt8]) -> [UInt8] {
		
		guard MiniSwCrypt.CMAC.available() else {
			assertionFailure("MiniSwCrypt.CMAC.available() == false")
			return [UInt8]()
		}

		let _key: Data = key.toData()
		let _data: Data = data.toData()
		
		let result = MiniSwCrypt.CMAC.AESCMAC(_data, key: _key)
		return result.toByteArray()
	}
	
	static func crc32(_ data: [UInt8]) -> [UInt8] {
		 
		guard MiniSwCrypt.CRC.available() else {
			assertionFailure("MiniSwCrypt.CRC.available() == false")
			return [UInt8]()
		}
		
		let _data: Data = data.toData()
		
		do {
			let rawVal: UInt64 = try MiniSwCrypt.CRC.crc(_data, mode: .crc32)
			let val = UInt32(rawVal)
			
			let basicCRC = val.littleEndian.toByteArray()
			let jamXorMask: [UInt8] = [0xff, 0xff, 0xff, 0xff]

			let jamCRC = Utils.xor(basicCRC, jamXorMask)
			return jamCRC
			
		} catch {
			assertionFailure("MiniSwCrypt.CRC.crc(): error: \(error)")
			return [UInt8]()
		}
	}
	
	static func randomBytes(ofLength length: Int) -> [UInt8] {
		var bytes = [UInt8](repeating: 0, count: length)
		let status = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)

		assert(status == errSecSuccess, "Bad mojo in randomBytes")

		return bytes
	}
}
