import Foundation
	
public struct BoltCardTemplate: Hashable {
	
	public enum Value: Hashable {
		case url(URL)
		case binary(Data)
	}
	
	public let value: Value
	public let data: [UInt8]
	public let headerLength: Int
	public let piccDataOffset: Int
	public let cmacOffset: Int
	
	public init?(baseUrl: URL) {
		
		guard var comps = URLComponents(url: baseUrl, resolvingAgainstBaseURL: false) else {
			return nil
		}
		
		var queryItems = comps.queryItems ?? []
		
		// The `baseUrl` SHOULD NOT have either `picc_data` or `cmac` parameters.
		// But just to be safe, we'll remove them if they're present.
		//
		queryItems.removeAll(where: { item in
			let name = item.name.lowercased()
			return name == "picc_data" || name == "cmac"
		})
		
		// picc_data=(16_bytes_hexadecimal)
		// cmac=(8_bytes_hexadecimal)
		
		queryItems.append(URLQueryItem(name: "picc_data", value: "00000000000000000000000000000000"))
		queryItems.append(URLQueryItem(name: "cmac",      value: "0000000000000000"))
		
		comps.queryItems = queryItems
		
		guard let resolvedUrl = comps.url else {
			return nil
		}
		
		let fileInfo = Ndef.fileForUrl(resolvedUrl)
		
		// Ultimately, the URL gets encoded as UTF-8,
		// and the offsets are used as indexes within this UTF-8 representation.
		//
		// So we need to do our calculations within the string's utf8View.
		
		let urlUtf8 = resolvedUrl.absoluteString.utf8
		
		guard let range1 = urlUtf8.ranges(of: "picc_data=".utf8).last else {
			return nil
		}
		let offset1 = urlUtf8.distance(from: urlUtf8.startIndex, to: range1.upperBound)
		
		guard let range2 = urlUtf8.ranges(of: "cmac=".utf8).last else {
			return nil
		}
		let offset2 = urlUtf8.distance(from: urlUtf8.startIndex, to: range2.upperBound)
		
		self.value = .url(resolvedUrl)
		self.data = fileInfo.data
		self.headerLength = fileInfo.headerLength
		self.piccDataOffset = fileInfo.headerLength + offset1
		self.cmacOffset = fileInfo.headerLength + offset2
	}
	
	/// These bytes are present as a header in the binary,
	/// signaling that the binary value is a bolt card.
	///
	public static let magicBytes = Data(fromHex: "E180")!
	
	public struct Flags: OptionSet, Sendable {
		public let rawValue: UInt8
		
		public init(rawValue: UInt8) {
			self.rawValue = rawValue
		}
		
		public func toData() -> Data {
			return rawValue.toByteArray().toData()
		}
		
		public static let TYPE_OFFER     = Flags(rawValue: 0b000)
		public static let TYPE_ADDRESS   = Flags(rawValue: 0b001)
		
		public static let CHAIN_MAINNET  = Flags(rawValue: 0b000)
		public static let CHAIN_OTHER    = Flags(rawValue: 0b010)
		
		public static let SUPPORT_BOLT12 = Flags(rawValue: 0b000)
		public static let SUPPORT_BOLT11 = Flags(rawValue: 0b100)
	}
	
	public struct ShortChainHash: Equatable, Sendable {
		public let bytes: Data
		
		public init(_ bytes: Data) {
			precondition(bytes.count == 4, "Invalid ShortChainHash length")
			self.bytes = bytes
		}
		
		public static let mainnet = ShortChainHash(Data(fromHex: "6fe28c0a")!)
		public static let testnet3 = ShortChainHash(Data(fromHex: "43497fd7")!)
		public static let testnet4 = ShortChainHash(Data(fromHex: "43f08bda")!)
	}
	
	private init(binary baseBinary: Data, flags: Flags, chain: ShortChainHash? = nil) {
		
		var prefix = BoltCardTemplate.magicBytes + flags.toData()
		if let chain {
			prefix += chain.bytes
		}
		
		let piccDataLength = 32
		let cmacDataLength = 16
		let suffix = Data(count: piccDataLength + cmacDataLength)
		
		let fullBinary = prefix + baseBinary + suffix
		
		let fileInfo = Ndef.fileForBinary(fullBinary)
		
		self.value = .binary(fullBinary)
		self.data = fileInfo.data
		self.headerLength = fileInfo.headerLength
		self.piccDataOffset = fileInfo.headerLength + prefix.count + baseBinary.count
		self.cmacOffset = fileInfo.headerLength + prefix.count + baseBinary.count + piccDataLength
	}
	
	public init(offer binaryOffer: Data, chain chainParam: ShortChainHash? = nil, supportsBolt12: Bool = true) {
		
		let chain = (chainParam == ShortChainHash.mainnet) ? nil : chainParam
		
		var flags = Flags.TYPE_OFFER
		flags = if (chain == nil) { flags.union(.CHAIN_MAINNET) } else { flags.union(.CHAIN_OTHER) }
		flags = if supportsBolt12 { flags.union(.SUPPORT_BOLT12) } else { flags.union(.SUPPORT_BOLT11) }
		
		self.init(binary: binaryOffer, flags: flags, chain: chain)
	}
	
	public init(address: String, chain chainParam: ShortChainHash? = nil, supportsBolt12: Bool = true) {
		
		let chain = (chainParam == ShortChainHash.mainnet) ? nil : chainParam
		
		var flags = Flags.TYPE_ADDRESS
		flags = if (chain == nil) { flags.union(.CHAIN_MAINNET) } else { flags.union(.CHAIN_OTHER) }
		flags = if supportsBolt12 { flags.union(.SUPPORT_BOLT12) } else { flags.union(.SUPPORT_BOLT11) }
		
		let addressData = address.data(using: .utf8) ?? Data()
		
		self.init(binary: addressData, flags: flags, chain: chain)
	}
	
	public struct DynamicValues {
		public let piccData: Data
		public let cmac: Data
		public let encString: String?
	}
	
	public enum ExtractionError: Error {
		case piccDataMissing
		case piccDataInvalid
		case cmacMissing
		case cmacInvalid
	}
	
	public static func extractDynamicValues(
		url: URL
	) -> Result<DynamicValues, ExtractionError> {
	
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
		
		return .success(DynamicValues(piccData: piccData, cmac: cmacData, encString: encString))
	}
	
	public static func extractDynamicValues(
		binary: Data
	) -> Result<DynamicValues, ExtractionError> {
		
		let expectedPrefix = BoltCardTemplate.magicBytes
		let piccDataLength = 32
		let cmacDataLength = 16
		let minLength = expectedPrefix.count + piccDataLength + cmacDataLength
		
		if binary.count < minLength {
			return .failure(.piccDataMissing)
		}
		
		if !binary.starts(with: expectedPrefix) {
			return .failure(.piccDataMissing)
		}
		
		let piccAndCmac = binary.suffix(piccDataLength + cmacDataLength)
		let piccRaw = piccAndCmac.prefix(piccDataLength)
		let cmacRaw = piccAndCmac.suffix(cmacDataLength)
		
		guard
			let piccString = String(data: piccRaw, encoding: .utf8),
			let piccData = Data(fromHex: piccString)
		else {
			return .failure(.piccDataInvalid)
		}
		
		guard
			let cmacString = String(data: cmacRaw, encoding: .utf8),
			let cmacData = Data(fromHex: cmacString)
		else {
			return .failure(.cmacInvalid)
		}
		
		return .success(DynamicValues(piccData: piccData, cmac: cmacData, encString: nil))
	}
}
