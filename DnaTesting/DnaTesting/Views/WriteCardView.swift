import SwiftUI
import OSLog
import DnaCommunicator

fileprivate let log = Logger.init(subsystem: "DnaTesting", category: "WriteCardView")

struct WriteCardView: View {
	
	@State var selectedKey: PresetKey = PresetKey.alice
	@State var selectedTemplate: PresetTemplate = PresetTemplate.a
	
	@State var isWriting: Bool = false
	@State var writeResult: Result<NfcWriter.WriteOutput, NfcWriter.WriteError>? = nil
	
	@ViewBuilder
	var body: some View {
		
		content()
			.navigationTitle("Write Card")
			.navigationBarTitleDisplayMode(.inline)
	}
	
	@ViewBuilder
	func content() -> some View {
		
		VStack(alignment: HorizontalAlignment.center, spacing: 60) {
			Form {
				section_key()
				section_template()
				section_button()
				if let result = writeResult {
					section_result(result)
				}
			}
		}
		.onAppear() {
			onAppear()
		}
	}
	
	@ViewBuilder
	func section_key() -> some View {
		
		Section {
			Picker("Select Key:", selection: $selectedKey) {
				let presetKeys = PresetKey.all()
				ForEach(0 ..< presetKeys.count, id: \.self) { index in
					let presetKey = presetKeys[index]
					Text(presetKey.name).tag(presetKey)
				}
			}
			.pickerStyle(.menu)
			
			Text("The card will be programmed with this key.")
				.font(.callout)
				.fixedSize(horizontal: false, vertical: true) // SwiftUI truncation bugs
				.foregroundColor(.secondary)
				.padding(.top, 8)
				.padding(.bottom, 4)
			
		} // </Section>
	}
	
	@ViewBuilder
	func section_template() -> some View {
		
		Section {
			Picker("Select Template:", selection: $selectedTemplate) {
				let presetTemplates = PresetTemplate.all()
				ForEach(0 ..< presetTemplates.count, id: \.self) { index in
					let presetTemplate = presetTemplates[index]
					Text(presetTemplate.name).tag(presetTemplate)
				}
			}
			.pickerStyle(.menu)
			
			Group {
				switch selectedTemplate.template.value {
				case .url(let url):
					Text(preventAutoHyphenation(url.absoluteString))
				case .binary(let binary):
					Text(preventAutoHyphenation(binary.toHex()))
				}
			}
			.font(.callout)
			.fixedSize(horizontal: false, vertical: true) // SwiftUI truncation bugs
			.foregroundColor(.secondary)
			.padding(.top, 8)
			.padding(.bottom, 4)
			
		} // </Section>
	}
	
	@ViewBuilder
	func section_button() -> some View {
		
		Section {
			HStack(alignment: VerticalAlignment.center, spacing: 0) {
				Spacer(minLength: 0)
				
				Button {
					startCardWriter()
				} label: {
					HStack {
						Image(systemName: "rectangle.and.pencil.and.ellipsis")
							.imageScale(.medium)
						Text("Write card")
							.font(.headline)
					}
				}
				.disabled(isWriting)
				
				Spacer(minLength: 0)
			} // </HStack>
			.padding(.vertical, 5)
			
		} // </Section>
	}
	
	@ViewBuilder
	func section_result(_ result: Result<NfcWriter.WriteOutput, NfcWriter.WriteError>) -> some View {
		
		switch result {
		case .success(_):
			section_result_success()
			
		case .failure(let error):
			section_result_error(error)
		}
	}
	
	@ViewBuilder
	func section_result_success() -> some View {
		
		Section {
			Text(
				"""
				The card has now been programmed. \
				You should now be able to read the card (and decrypt the values) \
				on the other screen.
				"""
			)
			
		} // </Section>
	}
	
	@ViewBuilder
	func section_result_error(_ error: NfcWriter.WriteError) -> some View {
		
		Section {
			VStack(alignment: HorizontalAlignment.leading, spacing: 10) {
				Text("An error has occurred:")
					.foregroundStyle(Color.red)
				
				switch error {
				case .readingNotAvailable:
					Text("NFC cababilities not available on this device")
				case .alreadyStarted:
					Text("NFC device is already in use")
				case .couldNotConnect:
					Text("Could not connect to NFC card")
				case .couldNotAuthenticate:
					Text("Could not authenticate with NFC card. The key is incorrect.")
				case .keySlotsUnavailable:
					Text(
						"""
						Key slots unavailable. \
						We need at least 2 key slots to re-program the card, \
						and we were unable to clear at least 2.
						"""
					)
				case .protocolError(let writeStep, let error):
					Text("Protocol error: \(writeStepName(writeStep))").bold()
					Text("Details: \(error.localizedDescription)")
					
				case .scanningTerminated(let nfcError):
					Text("NFC process terminated unexpectedly")
					Text("NFC error: \(nfcError.localizedDescription)")
				}
			}
		} // </Section>
	}
	
	// --------------------------------------------------
	// MARK: View Helpers
	// --------------------------------------------------
	
	func writeStepName(_ writeStep: NfcWriter.WriteStep) -> String {
		switch writeStep {
			case .readChipUid        : return "Read Chip UID"
			case .writeFile2Settings : return "Write File(2) Settings"
			case .writeFile2Data     : return "Write File(2) Data"
			case .writeKey0          : return "Write Key(0)"
		}
	}
	
	func preventAutoHyphenation(_ text: String) -> String {
		
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
	// MARK: Card Writer
	// --------------------------------------------------
	
	func startCardWriter() {
		log.trace(#function)
		
		isWriting = true
		writeResult = nil
		
		let input = NfcWriter.WriteInput(
			template: selectedTemplate.template,
			key0: selectedKey.keySet.key0.toByteArray(),
			piccDataKey: selectedKey.keySet.piccDataKey.toByteArray(),
			cmacKey: selectedKey.keySet.cmacKey.toByteArray()
		)
		
		NfcWriter.shared.writeCard(input) { result in
			
			isWriting = false
			switch result {
			case .success(_):
				writeResult = result
				
			case .failure(let error):
				var ignore = false
				if case .scanningTerminated(let reason) = error {
					ignore = reason.isIgnorable() // e.g. user tapped "cancel" button
				}
				if ignore {
					writeResult = nil
				} else {
					writeResult = result
				}
			}
		}
	}
}
