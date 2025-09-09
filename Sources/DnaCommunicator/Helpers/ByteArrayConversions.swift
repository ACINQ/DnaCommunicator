import Foundation

extension Array where Element == UInt8 {
	
	public func toData() -> Data {
		return Data(bytes: self, count: self.count)
	}
}

extension Data {
	
	public func toByteArray() -> [UInt8] {
		var buffer = [UInt8]()
		self.withUnsafeBytes {
			buffer.append(contentsOf: $0)
		}
		return buffer
	}
}

extension FixedWidthInteger {
	
	public func toByteArray() -> [UInt8] {
		withUnsafeBytes(of: self, Array.init)
	}
}
