/**
 * DnaCommunicator
 * For communicating with NFC tags of type NTAG 424 DNA.
 * https://github.com/ACINQ/DnaCommunicator
 *
 * Special thanks to Jonathan Bartlett.
 */

import Foundation

extension DnaCommunicator {
    
	public func readFileData(
		fileNum : FileSpecifier,
		offset  : Int = 0,
		length  : Int,
		mode    : CommuncationMode
	) async -> Result<[UInt8], Error> {
		
		// Pg. 73
		let offsetBytes = Int32(offset).littleEndian.toByteArray()[0...2]
		let lengthBytes = Int32(length).littleEndian.toByteArray()[0...2] // <- Bug fix
		
		let result = await nxpSwitchedCommand(
			mode    : mode,
			command : 0xad,
			header  : [fileNum.rawValue] + offsetBytes + lengthBytes,
			data    : []
		)
		
		switch result {
		case .failure(let error):
			return .failure(error)
			
		case .success(let result):
			if let error = makeErrorIfNotExpectedStatus(result) {
				return .failure(error)
			} else {
				return .success(result.data)
			}
		}
	}
	
	public func writeFileData(
		fileNum : FileSpecifier,
		offset  : Int = 0,
		data    : [UInt8],
		mode    : CommuncationMode
	) async -> Result<Void, Error> {
		
		// Pg. 75
		let offsetBytes = Int32(offset).littleEndian.toByteArray()[0...2]       // 3 bytes
		let dataSizeBytes = Int32(data.count).littleEndian.toByteArray()[0...2] // 3 bytes
		
		let result = await nxpSwitchedCommand(
			mode    : mode,
			command : 0x8d,
			header  : [fileNum.rawValue] + offsetBytes + dataSizeBytes,
			data    : data
		)
		
		switch result {
		case .failure(let err):
			return .failure(err)
			
		case .success(let result):
			if let err = makeErrorIfNotExpectedStatus(result) {
				return .failure(err)
			} else {
				return .success(())
			}
		}
	}
	
	public func getFileSettings(
		fileNum: FileSpecifier
	) async -> Result<FileSettings, Error> {
		
		// Pg. 69
		let result = await nxpMacCommand(
			command : 0xf5,
			header  : [fileNum.rawValue],
			data    : []
		)
		
		switch result {
		case .failure(let err):
			return .failure(err)
			
		case .success(let result):
			if let err = makeErrorIfNotExpectedStatus(result) {
				return .failure(err)
			}
			
			if let settings = FileSettings(data: result.data) {
				return .success(settings)
			} else {
				let err = Utils.makeError(110, "Invalid FileSettings response")
				return .failure(err)
			}
		}
	}
	
	public func changeFileSettings(
		fileNum : FileSpecifier,
		data    : [UInt8]
	) async -> Result<Void, Error> {
		
		// Pg. 65
		let result = await nxpEncryptedCommand(
			command : 0x5f,
			header  : [fileNum.rawValue],
			data    : data
		)
		
		switch result {
		case .failure(let err):
			return .failure(err)
			
		case .success(let result):
			if let err = makeErrorIfNotExpectedStatus(result) {
				return .failure(err)
			} else {
				return .success(())
			}
		}
	}
}
