import Foundation
import SwCrypt

extension Utils {
	
	static let zeroIV: [UInt8] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
	
	static func simpleAesEncrypt(key: [UInt8], data: [UInt8], iv: [UInt8] = zeroIV) -> [UInt8] {
		
		guard SwCrypt.CC.cryptorAvailable() else {
			assertionFailure("SwCrypt.CC.cryptorAvailable() == false")
			return [UInt8]()
		}
		
		let _key: Data = key.toData()
		let _data: Data = data.toData()
		let _iv: Data = iv.toData()
		
		do {
			let result = try SwCrypt.CC.crypt(
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
			assertionFailure("SwCrypt..crypt(): error: \(error)")
			return [UInt8]()
		}
	}
	
	static func simpleAesDecrypt(key: [UInt8], data: [UInt8], iv: [UInt8] = zeroIV) -> [UInt8] {
		
		guard SwCrypt.CC.cryptorAvailable() else {
			assertionFailure("SwCrypt.CC.cryptorAvailable() == false")
			return [UInt8]()
		}
		
		let _key: Data = key.toData()
		let _data: Data = data.toData()
		let _iv: Data = iv.toData()
		 
		do {
			let result = try SwCrypt.CC.crypt(
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
			assertionFailure("SwCrypt.CC.crypt(): error: \(error)")
			return [UInt8]()
		}
	}
	
	static func simpleCMAC(key: [UInt8], data: [UInt8]) -> [UInt8] {
		
		guard SwCrypt.CC.CMAC.available() else {
			assertionFailure("SwCrypt.CC.CMAC.available() == false")
			return [UInt8]()
		}

		let _key: Data = key.toData()
		let _data: Data = data.toData()
		
		let result = SwCrypt.CC.CMAC.AESCMAC(_data, key: _key)
		return result.toByteArray()
	}
	
	static func crc32(_ data: [UInt8]) -> [UInt8] {
		 
		guard SwCrypt.CC.CRC.available() else {
			assertionFailure("SwCrypt.CC.CRC.available() == false")
			return [UInt8]()
		}
		
		let _data: Data = data.toData()
		
		do {
			let rawVal: UInt64 = try SwCrypt.CC.CRC.crc(_data, mode: .crc32)
			let val = UInt32(rawVal)
			
			let basicCRC = val.littleEndian.toByteArray()
			let jamXorMask: [UInt8] = [0xff, 0xff, 0xff, 0xff]

			let jamCRC = Utils.xor(basicCRC, jamXorMask)
			return jamCRC
			
		} catch {
			assertionFailure("SwCrypt.CC.CRC.crc(): error: \(error)")
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
