/**
 * DnaCommunicator
 * For communicating with NFC tags of type NTAG 424 DNA.
 * https://github.com/ACINQ/DnaCommunicator
 *
 * Special thanks to Jonathan Bartlett.
 */

extension DnaCommunicator {
	
	public func getChipUid() async -> Result<[UInt8], Error> {
		
		let result = await nxpEncryptedCommand(command: 0x51, header: [], data: [])
		
		switch result {
		case .failure(let err):
			return .failure(err)
			
		case .success(let result):
			if let err = self.makeErrorIfNotExpectedStatus(result) {
				return .failure(err)
			} else {
				let uid = Array(result.data[0...6])
				return .success(uid)
			}
		}
	}
}
