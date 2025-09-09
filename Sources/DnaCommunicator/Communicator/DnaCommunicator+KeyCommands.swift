/**
 * DnaCommunicator
 * For communicating with NFC tags of type NTAG 424 DNA.
 * https://github.com/ACINQ/DnaCommunicator
 *
 * Special thanks to Jonathan Bartlett.
 */

import Foundation

extension DnaCommunicator {

	public func getKeyVersion(
		keyNum: KeySpecifier
	) async -> Result<UInt8, Error> {
		
		let result = await nxpMacCommand(
			command : 0x64,
			header  : [keyNum.rawValue],
			data    : nil
		)
		
		switch result {
		case .failure(let err):
			return .failure(err)
			
		case .success(let result):
			if let err = makeErrorIfNotExpectedStatus(result) {
				return .failure(err)
			} else {
				let resultValue = result.data.count < 1 ? 0 : result.data[0]
				return .success(resultValue)
			}
		}
	}
	
	public func changeKey(
		keyNum     : KeySpecifier,
		oldKey     : [UInt8],
		newKey     : [UInt8],
		keyVersion : UInt8
	) async -> Result<Void, Error> {
		
		if activeKeyNumber != .KEY_0 {
			log(
				"""
				Not sure if changing keys when not authenticated as key0 is allowed -\
				documentation is unclear
				"""
			)
		}
		
		var data: [UInt8] = []
		if (keyNum == .KEY_0) {
			// If we are changing key0, can just send the request
			data = newKey + [keyVersion]
			
		} else {
			// Weird validation methodology
			let crc = Utils.crc32(newKey)
			let xorkey = Utils.xor(oldKey, newKey)
			data = xorkey + [keyVersion] + crc
		}
		
		let result = await nxpEncryptedCommand(
			command : 0xc4,
			header  : [keyNum.rawValue],
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
