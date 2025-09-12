import Foundation

public class Ntag424 {
	
	public struct QueryItems {
		public let piccData: Data
		public let cmac: Data
		public let encString: String?
	}
	
	public enum QueryItemsError: Error {
		case piccDataMissing
		case piccDataInvalid
		case cmacMissing
		case cmacInvalid
	}
	
	public static func extractQueryItems(
		text: String
	) -> Result<QueryItems, QueryItemsError> {
		
		if let url = URL(string: "lightning:\(text)") {
			return extractQueryItems(url: url)
		} else {
			return .failure(.piccDataMissing)
		}
	}
	
	public static func extractQueryItems(
		url: URL
	) -> Result<QueryItems, QueryItemsError> {
	
		guard
			let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
			let queryItems = components.queryItems
		else {
			return .failure(.piccDataMissing)
		}
	
		var piccString: String? = nil
		var cmacString: String? = nil
		var encString: String? = nil
		
		for queryItem in queryItems {
			if queryItem.name.caseInsensitiveCompare("picc_data") == .orderedSame {
				piccString = queryItem.value
			} else if queryItem.name.caseInsensitiveCompare("cmac") == .orderedSame {
				cmacString = queryItem.value
			} else if queryItem.name.caseInsensitiveCompare("enc") == .orderedSame {
				encString = queryItem.value
			}
		}
	
		guard let piccString else {
			return .failure(.piccDataMissing)
		}
		
		guard let piccData = Data(fromHex: piccString) else {
			return .failure(.piccDataInvalid)
		}
		
		guard let cmacString else {
			return .failure(.cmacMissing)
		}
		
		guard let cmacData = Data(fromHex: cmacString) else {
			return .failure(.cmacInvalid)
		}
		
		return .success(QueryItems(piccData: piccData, cmac: cmacData, encString: encString))
	}
	
	public struct KeySet {
		public let piccDataKey: Data
		public let cmacKey: Data
		
		public init(piccDataKey: Data, cmacKey: Data) {
			self.piccDataKey = piccDataKey
			self.cmacKey = cmacKey
		}
		
		public static func `default`() -> KeySet {
			return KeySet(
				piccDataKey: Data(repeating: 0x00, count: 16),
				cmacKey: Data(repeating: 0x00, count: 16)
			)
		}
	}
	
	public struct PiccDataInfo {
		public let uid: Data       // 7 bytes
		public let counter: UInt32 // 3 bytes (actual size in decrypted data)
		
		public static let maxCounterValue: UInt32 = 0xffffff // 16,777,215 (it's only 3 bytes)
	}
	
	public enum ExtractionError: Error {
		case decryptionFailed
		case cmacCalculationFailed
		case cmacMismatch
	}
	
	public static func extractPiccDataInfo(
		piccData : Data,
		cmac     : Data,
		keySet   : KeySet
	) -> Result<PiccDataInfo, ExtractionError> {
		
		guard let tuple = decryptPiccData(piccData, keySet) else {
			return .failure(.decryptionFailed)
		}
		
		let decryptedPiccData = tuple.0
		let piccDataInfo = tuple.1
		
		guard let calculatedCmac = calculateCmac(decryptedPiccData, nil, keySet) else {
			return .failure(.cmacCalculationFailed)
		}
		
		guard calculatedCmac == cmac else {
			return .failure(.cmacMismatch)
		}
		
		return .success(piccDataInfo)
	}
	
	private static func decryptPiccData(
		_ encryptedPiccData: Data,
		_ keySet: KeySet
	) -> (Data, PiccDataInfo)? {
		
		guard let decryptedPiccData = decrypt(data: encryptedPiccData, key: keySet.piccDataKey) else {
			return nil
		}
		
		guard decryptedPiccData.count == 16 else {
			return nil
		}
		
		let piccDataHeader: UInt8 = 0xc7
		guard decryptedPiccData[0] == piccDataHeader else {
			return nil
		}
		
		let uid: Data = decryptedPiccData[1..<8]
		var ctr: Data = decryptedPiccData[8..<11]
		
		var counter: UInt32 = 0
		ctr.append(contentsOf: [0x00])
		ctr.withUnsafeBytes { ptr in
			let littleEndian = ptr.load(as: UInt32.self)
			counter = UInt32(littleEndian: littleEndian)
		}
		
		let result = PiccDataInfo(uid: uid, counter: counter)
		return (decryptedPiccData, result)
	}
	
	private static func calculateCmac(
		_ decryptedPiccData: Data,
		_ encString: String?,
		_ keySet: KeySet
	) -> Data? {
		
		var inputA = Data()
		inputA.append(contentsOf: [0x3C, 0xC3, 0x00, 0x01, 0x00, 0x80])
		inputA += decryptedPiccData[1..<11]
		
		while (inputA.count % 16) != 0 {
			inputA.append(contentsOf: [0x00])
		}
		
		guard let resultA: Data = cmac(data: inputA, key: keySet.cmacKey) else {
			return nil
		}
		
		var inputB = Data()
		if let encString {
			if let encData = encString.uppercased().data(using: .ascii) {
				inputB += encData
			}
			if let suffix = "&cmac=".data(using: .ascii) {
				inputB += suffix
			}
		}
		
		guard let resultB: Data = cmac(data: inputB, key: resultA) else {
			return nil
		}
		
		var truncated = Data()
		resultB.enumerated().forEach { (index, value) in
			if (index % 2) == 1 {
				truncated.append(contentsOf: [value])
			}
		}
		
		return truncated
	}
	
	private static func decrypt(
		data : Data,
		key  : Data
	) -> Data? {
		
		guard MiniSwCrypt.CC.available() else {
			return nil
		}
		
		do {
			let result = try MiniSwCrypt.CC.crypt(
				.decrypt,
				blockMode : .ecb,
				algorithm : .aes,
				padding   : .noPadding,
				data      : data,
				key       : key,
				iv        : Data(repeating: 0, count: 16) // not used in ECB mode
			)
			return result

		} catch {
			return nil
		}
	}
	
	private static func cmac(
		data : Data,
		key  : Data
	) -> Data? {
		
		guard MiniSwCrypt.CMAC.available() else {
			return nil
		}
		
		return MiniSwCrypt.CMAC.AESCMAC(data, key: key)
	}
}
