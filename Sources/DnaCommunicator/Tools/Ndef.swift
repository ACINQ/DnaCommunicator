import Foundation

public class Ndef {
	
	public struct HeaderFlags: OptionSet, Sendable {
		public let rawValue: UInt8
		
		public init(rawValue: UInt8) {
			self.rawValue = rawValue
		}
		
		/// Message begin flag
		public static let MB = HeaderFlags(rawValue: 0b10000000)
		/// Message end flag
		public static let ME = HeaderFlags(rawValue: 0b01000000)
		/// Chunked flag
		public static let CF = HeaderFlags(rawValue: 0b00100000)
		/// Short record flag
		public static let SR = HeaderFlags(rawValue: 0b00010000)
		/// IL (ID Length) is present
		public static let IL = HeaderFlags(rawValue: 0b00001000)
		
		/// Type Name Format options:
		public static let TNF_WELL_KNOWN   = HeaderFlags(rawValue: 0b00000001) // 0x01
		public static let TNF_MIME         = HeaderFlags(rawValue: 0b00000010) // 0x02
		/// Note: don't use this for URLS, use WELLKNOWN instead.
		public static let TNF_ABSOLUTE_URI = HeaderFlags(rawValue: 0b00000011) // 0x03
		public static let TNF_EXTERNAL     = HeaderFlags(rawValue: 0b00000100) // 0x04
		public static let TNF_UNKNOWN      = HeaderFlags(rawValue: 0b00000101) // 0x05
		public static let TNF_UNCHANGED    = HeaderFlags(rawValue: 0b00000110) // 0x06
		public static let TNF_RESERVED     = HeaderFlags(rawValue: 0b00000111) // 0x07
	}
	
	public enum HeaderType: UInt8 {
		case TEXT = 0x54 // 'T'.ascii
		case URL  = 0x55 // 'U'.ascii
	}
	
	public struct FileInfo {
		public let data: [UInt8]
		public let headerLength: Int
	}
	
	public class func fileForUrl(_ url: URL) -> FileInfo {
		
		// See pgs. 30-31 of AN12196
		
		// NFC Type 4 File Format:
		//
		// Field        | Length     | Description
		// ---------------------------------------------------------------
		// NLEN         | 2 bytes    | Length of the NDEF message in big-endian format.
		// NDEF Message | NLEN bytes | NDEF message. See NFC Data Exchange Format (NDEF).
		//
		// https://docs.nordicsemi.com/bundle/ncs-latest/page/nrfxlib/nfc/doc/type_4_tag.html#t4t-format
		//
		var fileHeader: [UInt8] = [
			0x00, // Placeholder for NLEN
			0x00, // Placeholder for NLEN
		]
		
		// Header for: Well-known-type(URL)
		//
		// Note: If you have a long URL that doesn't fit, you can change the typeHeader here.
		// For example, if you specify 0x02 for the typeHeader, it means:
		// - prepend `https://www.` to the URL content, saving a few bytes.
		//
		let typeHeader: [UInt8] = [
			0x00 // Just the URI (no prepended protocol)
		]
		
		let urlData = url.absoluteString.data(using: .utf8) ?? Data()
		let urlBytes =  urlData.toByteArray()
		
		// NDEF Message header:
		
		let messageHeader: [UInt8]
		
		let fitsInShortRecord = (typeHeader.count + urlBytes.count) <= 255
		if fitsInShortRecord {
			
			let payloadLength = UInt8(typeHeader.count + urlBytes.count)
			
			let flags: HeaderFlags = [.MB, .ME, .SR, .TNF_WELL_KNOWN]
			let type = HeaderType.URL
			
			messageHeader = [
				flags.rawValue, // NDEF header flags
				0x01,           // Type length
				payloadLength,  // Payload length (SR = 1 byte)
				type.rawValue   // Well-known type: URL
			]
			
		} else {
			
			let payloadLengthLE = UInt32(typeHeader.count + urlBytes.count)
			let payloadLength: [UInt8] = payloadLengthLE.bigEndian.toByteArray()
			
			let flags: HeaderFlags = [.MB, .ME, .TNF_WELL_KNOWN]
			let type = HeaderType.URL
			
			messageHeader = [
				flags.rawValue,   // NDEF header flags
				0x01,             // Type length
				payloadLength[0], // Payload length (!SR = 4 bytes)
				payloadLength[1], // Payload length
				payloadLength[2], // Payload length
				payloadLength[3], // Payload length
				type.rawValue     // Well-known type: URL
			]
		}
		
		let fileLengthLE = UInt16(messageHeader.count + typeHeader.count + urlBytes.count)
		let fileLength: [UInt8] = fileLengthLE.bigEndian.toByteArray()
		
		fileHeader[0] = fileLength[0]
		fileHeader[1] = fileLength[1]
		
		let header: [UInt8] = fileHeader + messageHeader + typeHeader
		let data: [UInt8] = header + urlBytes
		
		return FileInfo(data: data, headerLength: header.count)
	}
	
	public class func fileForText(_ text: String) -> FileInfo {
		
		// See pgs. 30-31 of AN12196
		
		// NFC Type 4 File Format:
		//
		// Field        | Length     | Description
		// ---------------------------------------------------------------
		// NLEN         | 2 bytes    | Length of the NDEF message in big-endian format.
		// NDEF Message | NLEN bytes | NDEF message. See NFC Data Exchange Format (NDEF).
		//
		// https://docs.nordicsemi.com/bundle/ncs-latest/page/nrfxlib/nfc/doc/type_4_tag.html#t4t-format
		//
		var fileHeader: [UInt8] = [
			0x00, // Placeholder for NLEN
			0x00  // Placeholder for NLEN
		]
		
		// Header for: Well-known-type(TEXT)
		//
		// RTD TEXT specification:
		//
		// Byte 0 bit pattern:
		//
		// |     7    |    6     |   5, 4, 3, 2, 1, 0   |
		// ----------------------------------------------
		// | UTF 8/16 | Reserved | Language code length |
		//
		// UTF-8  => 0
		// UTF-16 => 1
		//
		// Reserved => must be 0
		//
		// Language code should use ISO/IANA language code.
		// We will use "en" - although for our use case it will be ignored.
		//
		// Thus our bit pattern is:
		// 0b00000010 = 0x02
		//
		let typeHeader: [UInt8] = [
			0x02, // UTF-8; langCode.length = 2
			0x65, // 'e'
			0x6e  // 'n'
		]
		
		let textData = text.data(using: .utf8) ?? Data()
		let textBytes = textData.toByteArray()
		
		// NDEF Message header:
		
		let messageHeader: [UInt8]
		
		let fitsInShortRecord = (typeHeader.count + textBytes.count) <= 255
		if fitsInShortRecord {
			
			let payloadLength = UInt8(typeHeader.count + textBytes.count)
			
			let flags: HeaderFlags = [.MB, .ME, .SR, .TNF_WELL_KNOWN]
			let type = HeaderType.TEXT
			
			messageHeader = [
				flags.rawValue, // NDEF header flags
				0x01,           // Type length
				payloadLength,  // Payload length (SR = 1 byte)
				type.rawValue   // Well-known type: TEXT
			]
			
		} else {
			
			let payloadLengthLE = UInt32(typeHeader.count + textBytes.count)
			let payloadLength: [UInt8] = payloadLengthLE.bigEndian.toByteArray()
			
			let flags: HeaderFlags = [.MB, .ME, .TNF_WELL_KNOWN]
			let type = HeaderType.URL
			
			messageHeader = [
				flags.rawValue,   // NDEF header flags
				0x01,             // Type length
				payloadLength[0], // Payload length (!SR = 4 bytes)
				payloadLength[1], // Payload length
				payloadLength[2], // Payload length
				payloadLength[3], // Payload length
				type.rawValue     // Well-known type: URL
			]
		}
		
		let fileLengthLE = UInt16(messageHeader.count + typeHeader.count + textBytes.count)
		let fileLength: [UInt8] = fileLengthLE.bigEndian.toByteArray()
		
		fileHeader[0] = fileLength[0]
		fileHeader[1] = fileLength[1]
		
		let header: [UInt8] = fileHeader + messageHeader + typeHeader
		let data: [UInt8] = header + textBytes
		
		return FileInfo(data: data, headerLength: header.count)
	}
	
	public class func fileForBinary(_ binary: Data) -> FileInfo {
		
		// NFC Type 4 File Format:
		//
		// Field        | Length     | Description
		// ---------------------------------------------------------------
		// NLEN         | 2 bytes    | Length of the NDEF message in big-endian format.
		// NDEF Message | NLEN bytes | NDEF message. See NFC Data Exchange Format (NDEF).
		//
		// https://docs.nordicsemi.com/bundle/ncs-latest/page/nrfxlib/nfc/doc/type_4_tag.html#t4t-format
		//
		var fileHeader: [UInt8] = [
			0x00, // Placeholder for NLEN
			0x00  // Placeholder for NLEN
		]
		
		// NDEF Message header:
		
		let messageHeader: [UInt8]
		
		let fitsInShortRecord = binary.count <= 255
		if fitsInShortRecord {
			
			let payloadLength = UInt8(binary.count)
			
			let flags: HeaderFlags = [.MB, .ME, .SR, .TNF_UNKNOWN]
			let type = HeaderType.TEXT
			
			messageHeader = [
				flags.rawValue, // NDEF header flags
				0x00,           // Type length
				payloadLength   // Payload length (SR = 1 byte)
			]
			
		} else {
			
			let payloadLengthLE = UInt32(binary.count)
			let payloadLength: [UInt8] = payloadLengthLE.bigEndian.toByteArray()
			
			let flags: HeaderFlags = [.MB, .ME, .TNF_UNKNOWN]
			let type = HeaderType.URL
			
			messageHeader = [
				flags.rawValue,   // NDEF header flags
				0x00,             // Type length
				payloadLength[0], // Payload length (!SR = 4 bytes)
				payloadLength[1], // Payload length
				payloadLength[2], // Payload length
				payloadLength[3]  // Payload length
			]
		}
		
		let fileLengthLE = UInt16(messageHeader.count + binary.count)
		let fileLength: [UInt8] = fileLengthLE.bigEndian.toByteArray()
		
		fileHeader[0] = fileLength[0]
		fileHeader[1] = fileLength[1]
		
		let header: [UInt8] = fileHeader + messageHeader
		let data: [UInt8] = header + binary
		
		return FileInfo(data: data, headerLength: header.count)
	}
}
