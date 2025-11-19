import Foundation

class Utils {
	
	static func leftNibble(_ data: UInt8) -> UInt8 {
		return (data >> 4)
	}
	
	static func rightNibble(_ data: UInt8) -> UInt8 {
		return (data & UInt8(15))
	}
	
	static func rotateLeft(_ value: [UInt8], _ numRots:Int = 1) -> [UInt8] {
		var newAry = [UInt8](repeating: 0, count: value.count)
		var idx = 0
		while idx < value.count {
		let newIdx = (idx < numRots) ? (value.count - (numRots + idx)) : (idx - numRots)
			newAry[newIdx] = value[idx]
			idx += 1
		}
		return newAry
	}
	
	static func rotateRight(_ value: [UInt8], _ numRots:Int = 1) -> [UInt8] {
		var newAry = [UInt8](repeating: 0, count: value.count)
		var idx = 0
		while idx < value.count {
		let newIdx = (idx >= (value.count - numRots)) ? (idx - value.count + numRots) : (idx + numRots)
			newAry[newIdx] = value[idx]
			idx += 1
		}
		return newAry
	}
	
	static func xor(_ value1: UInt8, _ value2: UInt8) -> UInt8 {
		return (value1 | value2) - (value1 & value2)
	}
	
	static func xor(_ value1: [UInt8], _ value2: [UInt8]) -> [UInt8] {
		guard value1.count == value2.count else {
			assertionFailure("value1 and value2 must have the same length")
			return []
		}
		var newValue = [UInt8](repeating: 0, count: value1.count)
		for idx in 0...(value1.count - 1) {
			newValue[idx] = xor(value1[idx], value2[idx])
		}

		return newValue
	}
	
	static func evensOnly(_ data: [UInt8]) -> [UInt8] {
		var newData = [UInt8](repeating: 0, count: data.count / 2)
		var idx = 0
		while idx < newData.count {
			newData[idx] = data[idx * 2 + 1]
			idx += 1
		}
		return newData
	}
	
	static func getBitLSB(_ byte: UInt8, _ index: Int) -> Bool {
		let mask = UInt8(1 << index)
		let result = byte & mask
		return result != 0
	}
	
	static func messageWithPadding(_ message: [UInt8]) -> [UInt8] {
		let blockSize = 16
		
		// From page 24:
		//
		// > Padding is applied according to Padding Method 2 of ISO/IEC 9797-1 [7],
		// > i.e. by adding always 80h followed, if required, by zero bytes until a
		// > string with a length of a multiple of 16 byte is obtained. Note that if
		// > the plain data is a multiple of 16 bytes already, an additional padding
		// > block is added. The only exception is during the authentication itself
		// > (AuthenticateEV2First and AuthenticateEV2NonFirst), where no padding is
		// > applied at all.
		//
		// This helper method isn't used during AuthenticateEV2First, so we always
		// need to add padding here.
		
		let blocks = message.count / blockSize
		var result = [UInt8](repeating: 0, count: (blocks + 1)*blockSize)
		
		// Copy existing message
		var idx = 0
		while idx < message.count {
			result[idx] = message[idx]
			idx += 1
		}
		
		// Add the boundary marker
		result[message.count] = 0x80
		
		return result
	}
	
	static func makeError(_ code: Int, _ message: String) -> Error {
		return NSError(domain: "DNA", code: code, userInfo: ["message":message])
	}
}
