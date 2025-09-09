/**
 * DnaCommunicator
 * For communicating with NFC tags of type NTAG 424 DNA.
 * https://github.com/ACINQ/DnaCommunicator
 *
 * Special thanks to Jonathan Bartlett.
 */

import Foundation

public enum FileSettingsEncodingError: Error {
	case sdmUidOffsetRequired
	case sdmReadCounterOffsetRequired
	case sdmPiccDataOffsetRequired
	case sdmMacInputOffsetRequired
	case sdmEncOffsetRequired
	case sdmEncLengthRequired
	case sdmMacOffsetRequired
	case sdmReadCounterLimitRequired
}

public struct FileSettings {
	
	public static let minByteCount: Int = 7
	
	public var fileType: UInt8 = 0
	public var sdmEnabled: Bool = false
	public var communicationMode: CommuncationMode = .PLAIN
	public var readPermission: Permission = .NONE
	public var writePermission: Permission = .NONE
	public var readWritePermission: Permission = .NONE
	public var changePermission: Permission = .NONE
	public var fileSize: UInt32 = 0
	public var sdmOptionUid: Bool = false
	public var sdmOptionReadCounter: Bool = false
	public var sdmOptionReadCounterLimit: Bool = false
	public var sdmOptionEncryptFileData: Bool = false
	public var sdmOptionUseAscii: Bool = false
	public var sdmMetaReadPermission: Permission = .NONE
	public var sdmFileReadPermission: Permission = .NONE
	public var sdmReadCounterRetrievalPermission: Permission = .NONE
	public var sdmUidOffset: UInt32?
	public var sdmReadCounterOffset: UInt32?
	public var sdmPiccDataOffset: UInt32?
	public var sdmMacInputOffset: UInt32?
	public var sdmMacOffset: UInt32?
	public var sdmEncOffset: UInt32?
	public var sdmEncLength: UInt32?
	public var sdmReadCounterLimit: UInt32?
	
	public init() {}
	
	public init?(data: [UInt8]) {
		// Pg. 13
		
		guard data.count >= FileSettings.minByteCount else { return nil }
		
		self.fileType = data[0]
		let options = data[1]
		self.sdmEnabled = Utils.getBitLSB(options, 6)
		
		if Utils.getBitLSB(options, 0) {
			if Utils.getBitLSB(options, 1) {
				self.communicationMode = .FULL
			} else {
				self.communicationMode = .MAC
			}
		}
		
		readPermission = Permission(from: Utils.leftNibble(data[3]))
		writePermission = Permission(from: Utils.rightNibble(data[3]))
		readWritePermission = Permission(from: Utils.leftNibble(data[2]))
		changePermission = Permission(from: Utils.rightNibble(data[2]))
		
		fileSize = data.readLittleEndian(offset: 4, length: 3, as: UInt32.self)
		
		var currentOffset = 7
		
		if sdmEnabled {
			
			guard data.count >= (currentOffset + 3) else { return nil }
			
			let sdmOptions = data[currentOffset]
			currentOffset += 1
			 
			sdmOptionUid = Utils.getBitLSB(sdmOptions, 7)
			sdmOptionReadCounter = Utils.getBitLSB(sdmOptions, 6)
			sdmOptionReadCounterLimit = Utils.getBitLSB(sdmOptions, 5)
			sdmOptionEncryptFileData = Utils.getBitLSB(sdmOptions, 4)
			sdmOptionUseAscii = Utils.getBitLSB(sdmOptions, 0)
			
			let sdmAccessRights1 = data[currentOffset]
			currentOffset += 1
			let sdmAccessRights2 = data[currentOffset]
			currentOffset += 1
			sdmMetaReadPermission = Permission(from: Utils.leftNibble(sdmAccessRights2))
			sdmFileReadPermission = Permission(from: Utils.rightNibble(sdmAccessRights2))
			sdmReadCounterRetrievalPermission = Permission(from: Utils.rightNibble(sdmAccessRights1))
			 
			if sdmMetaReadPermission == .ALL {
				if sdmOptionUid {
					guard data.count >= (currentOffset + 3) else { return nil }
					sdmUidOffset = data.readLittleEndian(offset: currentOffset, length: 3, as: UInt32.self)
					currentOffset += 3
				}
				if sdmOptionReadCounter {
					guard data.count >= (currentOffset + 3) else { return nil }
					sdmReadCounterOffset = data.readLittleEndian(offset: currentOffset, length: 3, as: UInt32.self)
					currentOffset += 3
				}
			} else if sdmMetaReadPermission != .NONE {
				guard data.count >= (currentOffset + 3) else { return nil }
				sdmPiccDataOffset = data.readLittleEndian(offset: currentOffset, length: 3, as: UInt32.self)
				currentOffset += 3
			}

			if sdmFileReadPermission != .NONE {
				guard data.count >= (currentOffset + 3) else { return nil }
				sdmMacInputOffset = data.readLittleEndian(offset: currentOffset, length: 3, as: UInt32.self)
				currentOffset += 3
				
				if sdmOptionEncryptFileData {
					guard data.count >= (currentOffset + 6) else { return nil }
					sdmEncOffset = data.readLittleEndian(offset: currentOffset, length: 3, as: UInt32.self)
					currentOffset += 3
					sdmEncLength = data.readLittleEndian(offset: currentOffset, length: 3, as: UInt32.self)
					currentOffset += 3
				}
				
				guard data.count >= (currentOffset + 3) else { return nil }
				sdmMacOffset = data.readLittleEndian(offset: currentOffset, length: 3, as: UInt32.self)
				currentOffset += 3
			}

			if sdmOptionReadCounterLimit {
				guard data.count >= (currentOffset + 3) else { return nil }
				sdmReadCounterLimit = data.readLittleEndian(offset: currentOffset, length: 3, as: UInt32.self)
				currentOffset += 3
			}
		}
	}
	
	public enum EncodingMode {
		case GetFileSettings
		case ChangeFileSettings
	}
	
	public func encode(
		mode: EncodingMode = .ChangeFileSettings
	) -> Result<[UInt8], FileSettingsEncodingError> {
		
		var buffer: [UInt8] = Array<UInt8>()
		
		if mode == .GetFileSettings {
			buffer.append(fileType)
		}
		
		do { // File Options
			
			let maskA: UInt8 = sdmEnabled ? 0b01000000 : 0b00000000
			
			let maskB: UInt8
			switch communicationMode {
				case .PLAIN : maskB = 0b00000000
				case .MAC   : maskB = 0b00000001
				case .FULL  : maskB = 0b00000011
			}
			
			let fileOptions: UInt8 = maskA | maskB
			buffer.append(fileOptions)
		}
		do { // Access Rights
			
			let byteA: UInt8 = readWritePermission.rawValue << 4 | changePermission.rawValue
			let byteB: UInt8 = readPermission.rawValue << 4 | writePermission.rawValue
			
			buffer.append(byteA)
			buffer.append(byteB)
		}
		if mode == .GetFileSettings { // File Size
			
			let bytes = fileSize.littleEndian.toByteArray()[0...2]
			buffer.append(contentsOf: bytes)
			
		}
		if sdmEnabled {
			
			do { // SDM Options
				
				let maskA: UInt8 = sdmOptionUid              ? 0b10000000 : 0b00000000 // bit 7
				let maskB: UInt8 = sdmOptionReadCounter      ? 0b01000000 : 0b00000000 // bit 6
				let maskC: UInt8 = sdmOptionReadCounterLimit ? 0b00100000 : 0b00000000 // bit 5
				let maskD: UInt8 = sdmOptionEncryptFileData  ? 0b00010000 : 0b00000000 // bit 4
				let maskE: UInt8 = sdmOptionUseAscii         ? 0b00000001 : 0b00000000 // bit 0
				
				let options: UInt8 = maskA | maskB | maskC | maskD | maskE
				buffer.append(options)
			}
			do { // SDM Access Rights
				
				let byteA: UInt8 = 0xF << 4 | sdmReadCounterRetrievalPermission.rawValue
				let byteB: UInt8 = sdmMetaReadPermission.rawValue << 4 | sdmFileReadPermission.rawValue
				
				buffer.append(byteA)
				buffer.append(byteB)
			}
			
			if sdmMetaReadPermission == .ALL {
				if sdmOptionUid {
					if let sdmUidOffset {
						let bytes = sdmUidOffset.littleEndian.toByteArray()[0...2]
						buffer.append(contentsOf: bytes)
					} else {
						return .failure(.sdmUidOffsetRequired)
					}
				}
				if sdmOptionReadCounter {
					if let sdmReadCounterOffset {
						let bytes = sdmReadCounterOffset.littleEndian.toByteArray()[0...2]
						buffer.append(contentsOf: bytes)
					} else {
						return .failure(.sdmReadCounterOffsetRequired)
					}
				}
			} else if sdmMetaReadPermission != .NONE {
				if let sdmPiccDataOffset {
					let bytes = sdmPiccDataOffset.littleEndian.toByteArray()[0...2]
					buffer.append(contentsOf: bytes)
				} else {
					return .failure(.sdmPiccDataOffsetRequired)
				}
			}
			
			if sdmFileReadPermission != .NONE {
				if let sdmMacInputOffset {
					let bytes = sdmMacInputOffset.littleEndian.toByteArray()[0...2]
					buffer.append(contentsOf: bytes)
				} else {
					return .failure(.sdmMacInputOffsetRequired)
				}
				
				if sdmOptionEncryptFileData {
					if let sdmEncOffset {
						let bytes = sdmEncOffset.littleEndian.toByteArray()[0...2]
						buffer.append(contentsOf: bytes)
					} else {
						return .failure(.sdmEncOffsetRequired)
					}
					
					if let sdmEncLength {
						let bytes = sdmEncLength.littleEndian.toByteArray()[0...2]
						buffer.append(contentsOf: bytes)
					} else {
						return .failure(.sdmEncLengthRequired)
					}
				}
				
				if let sdmMacOffset {
					let bytes = sdmMacOffset.littleEndian.toByteArray()[0...2]
					buffer.append(contentsOf: bytes)
				} else {
					return .failure(.sdmMacOffsetRequired)
				}
			}
			
			if sdmOptionReadCounterLimit {
				if let sdmReadCounterLimit {
					let bytes = sdmReadCounterLimit.littleEndian.toByteArray()[0...2]
					buffer.append(contentsOf: bytes)
				} else {
					return .failure(.sdmReadCounterLimitRequired)
				}
			}
		}
		
		return .success(buffer)
	}
	
	public static func defaultFile1() -> FileSettings {
		
		var settings = FileSettings()
		settings.readPermission = .ALL
		settings.writePermission = .KEY_0
		settings.readWritePermission = .KEY_0
		settings.changePermission = .KEY_0
		settings.fileSize = 32
		
		return settings
	}
	
	public static func defaultFile2() -> FileSettings {
		
		var settings = FileSettings()
		settings.readPermission = .ALL
		settings.writePermission = .ALL
		settings.readWritePermission = .ALL
		settings.changePermission = .KEY_0
		settings.fileSize = 256
		
		return settings
	}
	
	public static func defaultFile3() -> FileSettings {
		
		var settings = FileSettings()
		settings.communicationMode = .FULL
		settings.readPermission = .KEY_2
		settings.writePermission = .KEY_3
		settings.readWritePermission = .KEY_3
		settings.changePermission = .KEY_0
		settings.fileSize = 128
		
		return settings
	}
}
