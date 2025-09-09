import SwiftUI
import CoreNFC
import OSLog
import DnaCommunicator

fileprivate let log = Logger.init(subsystem: "DnaTesting", category: "ReadCardView")

enum CardReadResult {
	case uri(URL)
	case text(String)
	case error(String)
}

enum CardDecryptResult {
	case success(CardDecryptInfo)
	case error(String)
}

struct CardDecryptInfo {
	let matchingKey: PresetKey
	let piccDataInfo: Ntag424.PiccDataInfo
}

struct ReadCardView: View {
	
	@State var isReading: Bool = false
	@State var readResult: CardReadResult? = nil
	@State var decryptResult: CardDecryptResult? = nil
	
	@ViewBuilder
	var body: some View {
		
		content()
			.navigationTitle("Read Card")
			.navigationBarTitleDisplayMode(.inline)
	}
	
	@ViewBuilder
	func content() -> some View {
		
		VStack(alignment: HorizontalAlignment.center, spacing: 60) {
			Form {
				section_button()
				if let result = readResult {
					section_readResult(result)
				}
				if let result = decryptResult {
					section_decryptResult(result)
				}
				if (readResult == nil) && (decryptResult == nil) {
					section_explanation()
				}
			}
		}
		.onAppear() {
			onAppear()
		}
	}
	
	@ViewBuilder
	func section_button() -> some View {
		
		Section {
			HStack(alignment: VerticalAlignment.center, spacing: 0) {
				Spacer(minLength: 0)
				
				Button {
					startCardReader()
				} label: {
					HStack {
						Image(systemName: "list.bullet.clipboard")
							.imageScale(.medium)
						Text("Read card")
							.font(.headline)
					}
				}
				.disabled(isReading)
				
				Spacer(minLength: 0)
			} // </HStack>
			.padding(.vertical, 5)
			
		} // </Section>
	}
	
	@ViewBuilder
	func section_readResult(_ result: CardReadResult) -> some View {
		
		Section {
			
			switch result {
			case .uri(let url):
				let link = url.absoluteString
				Button {
					openUrl(url)
				} label: {
					Text(preventAutoHyphenation(link))
						.multilineTextAlignment(.leading)
						.contextMenu {
							Button {
								copyToPasteboard(link)
							} label: {
								Text("Copy")
							}
						} // </contextMenu>
				}
				
			case .text(let text):
				Text(preventAutoHyphenation(text))
					.contextMenu {
						Button {
							copyToPasteboard(text)
						} label: {
							Text("Copy")
						}
					} // </contextMenu>
				
			case .error(let errorMessage):
				Text(errorMessage)
					.multilineTextAlignment(.leading)
					.foregroundStyle(Color.red)
			}
			
		} header: {
			Text("Read Result")
		}
	}
	
	@ViewBuilder
	func section_decryptResult(_ result: CardDecryptResult) -> some View {
		
		Section {
			
			switch result {
			case .success(let info):
				
				HStack(alignment: VerticalAlignment.firstTextBaseline, spacing: 0) {
					Text("Matching Key:").foregroundStyle(.secondary)
					Spacer(minLength: 10)
					Text(info.matchingKey.name)
				}
				
				HStack(alignment: VerticalAlignment.firstTextBaseline, spacing: 0) {
					Text("Card UID:").foregroundStyle(.secondary)
					Spacer(minLength: 10)
					Text(info.piccDataInfo.uid.toHex())
				}
				
				HStack(alignment: VerticalAlignment.firstTextBaseline, spacing: 0) {
					Text("Card Counter:").foregroundStyle(.secondary)
					Spacer(minLength: 10)
					Text("\(info.piccDataInfo.counter)")
				}
				
			case .error(let errorMessage):
				Text(errorMessage)
					.multilineTextAlignment(.leading)
					.foregroundStyle(Color.red)
			}
			
		} header: {
			Text("Decrypt Result")
		}
	}
	
	@ViewBuilder
	func section_explanation() -> some View {
		
		Section {
			Text(
				"""
				After you read an NFC tag, we will look for query items. \
				If found, we will try to decrypt them using the list of preset keys.
				"""
			)
			.font(.callout)
			.fixedSize(horizontal: false, vertical: true) // SwiftUI truncation bugs
			.foregroundColor(.secondary)
			.padding(.top, 8)
			.padding(.bottom, 4)
			
		} // </Section>
	}
	
	// --------------------------------------------------
	// MARK: View Helpers
	// --------------------------------------------------
	
	func preventAutoHyphenation(_ text: String) -> String {
		
		// The URL is long because of the query parameters.
		// When SwiftUI displays long text, it automatically adds
		// hyphen characters at the end of some lines.
		//
		// E.g.
		// id=3fabbe50&picc_data=FB9B4202A7-  <- added hyphen
		// C37842120BE2D...
		//
		// I don't like this. And there's a simple way to prevent it.
		// You just add zero-width characters in-between every character
		// in the string.
		//
		// https://stackoverflow.com/q/78208090
		//
		
		return text.map({ String($0) }).joined(separator: "\u{200B}")
	}
	
	// --------------------------------------------------
	// MARK: Notifications
	// --------------------------------------------------
	
	func onAppear() {
		log.trace(#function)
	}
	
	// --------------------------------------------------
	// MARK: Card Reader
	// --------------------------------------------------
	
	func startCardReader() {
		log.trace(#function)
		
		isReading = true
		readResult = nil
		decryptResult = nil
		
		NfcReader.shared.readCard { result in
			
			isReading = false
			switch result {
			case .success(let message):
				handleCardReaderMessage(message)
				
			case .failure(let error):
				handleCardReaderError(error)
			}
		}
	}
	
	func handleCardReaderMessage(_ message: NFCNDEFMessage) {
		log.trace(#function)
		log.debug("NFCNDEFMessage: \(message)")
		
		var detectedUri: URL? = nil
		var detectedText: String? = nil
		
		message.records.forEach { payload in
			if let uri = payload.wellKnownTypeURIPayload() {
				log.debug("found uri = \(uri)")
				if detectedUri == nil {
					detectedUri = uri
				}
				
			} else if let text = payload.wellKnownTypeTextPayload().0 {
				log.debug("found text = \(text)")
				if detectedText == nil {
					detectedText = text
				}
				
			} else {
				log.debug("found tag with unknown type")
			}
		}
		
		if let detectedUri {
			readResult = .uri(detectedUri)
			tryExtractQueryItems()
			
		} else if let detectedText {
			readResult = .text(detectedText)
			tryExtractQueryItems()
			
		} else {
			readResult = .error("No URI or Text detected in NFC tag")
		}
	}
	
	func handleCardReaderError(_ error: NfcReader.ReadError) {
		log.trace(#function)
		
		switch error {
		case .readingNotAvailable:
			readResult = .error("NFC cababilities not available on this device")
		case .alreadyStarted:
			readResult = .error("NFC device is already in use")
		case .scanningTerminated(let reason):
			if reason.isIgnorable() {
				readResult = nil
			} else {
				readResult = .error("Error reading tag")
			}
		}
	}
	
	// --------------------------------------------------
	// MARK: Utilities
	// --------------------------------------------------
	
	func tryExtractQueryItems() {
		log.trace(#function)
		
		guard let readResult else { return }
		
		let extractResult: Result<Ntag424.QueryItems, Ntag424.QueryItemsError>? = switch readResult {
		case .uri(let url):
			Ntag424.extractQueryItems(url: url)
		case .text(let text):
			Ntag424.extractQueryItems(text: text)
		case .error(_):
			nil
		}
		
		guard let extractResult else { return }
		
		switch extractResult {
		case .success(let queryItems):
			tryMatchPresetKey(queryItems)
			
		case .failure(let reason):
			switch reason {
			case .piccDataMissing:
				// This is the expected error message if value is something else,
				// like a simple URL or text value.
				decryptResult = nil
			case .piccDataInvalid:
				decryptResult = .error("Unable to extract query items: picc_data is invalid")
			case .cmacMissing:
				decryptResult = .error("Unable to extract query items: cmac is missing")
			case .cmacInvalid:
				decryptResult = .error("Unable to extract query items: cmac is invalid")
			}
		}
	}
	
	func tryMatchPresetKey(_ queryItems: Ntag424.QueryItems) {
		log.trace(#function)
		
		var matchingKey: PresetKey? = nil
		var piccDataInfo: Ntag424.PiccDataInfo? = nil
		
		outerloop: for presetKey in PresetKey.all() {
			
			let keySet = Ntag424.KeySet(
				piccDataKey : presetKey.keySet.piccDataKey,
				cmacKey     : presetKey.keySet.cmacKey
			)
			let result = Ntag424.extractPiccDataInfo(
				piccData : queryItems.piccData,
				cmac     : queryItems.cmac,
				keySet   : keySet
			)

			switch result {
			case .failure(let reason):
				switch reason {
				case .decryptionFailed:
					// This is the expected error message if attempting to decrypt with incorrect key
					log.error("presetKey[\(presetKey.name)]: decrypt error: decryption failed")
					break
				case .cmacCalculationFailed:
					log.error("presetKey[\(presetKey.name)]: decrypt error: cmac calculation failed")
				case .cmacMismatch:
					log.error("presetKey[\(presetKey.name)]: decrypt error: cmac mismatch")
				}

			case .success(let result):
				log.debug("presetKey[\(presetKey.name)]: success")

				matchingKey = presetKey
				piccDataInfo = result
				break outerloop
			}
		}
		
		if let matchingKey, let piccDataInfo {
			decryptResult = .success(CardDecryptInfo(matchingKey: matchingKey, piccDataInfo: piccDataInfo))
		} else {
			decryptResult = .error("No matching preset key")
		}
	}
	
	// --------------------------------------------------
	// MARK: Actions
	// --------------------------------------------------
	
	func openUrl(_ url: URL) {
		log.trace(#function)
		
		if UIApplication.shared.canOpenURL(url) {
			UIApplication.shared.open(url)
		}
	}
	
	func copyToPasteboard(_ str: String) {
		log.trace(#function)
		
		UIPasteboard.general.string = str
	}
}
