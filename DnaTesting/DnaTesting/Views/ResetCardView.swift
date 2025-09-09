import SwiftUI
import OSLog
import DnaCommunicator

fileprivate let log = Logger.init(subsystem: "DnaTesting", category: "ResetCardView")

struct ResetCardView: View {
	
	@State var selectedKey: PresetKey = PresetKey.alice
	@State var isWriting: Bool = false
	@State var resetResult: Result<Void, NfcWriter.WriteError>? = nil
	
	@ViewBuilder
	var body: some View {
		
		content()
			.navigationTitle("Reset Card")
			.navigationBarTitleDisplayMode(.inline)
	}
	
	@ViewBuilder
	func content() -> some View {
		
		VStack(alignment: HorizontalAlignment.center, spacing: 60) {
			Form {
				section_key()
				section_button()
				if let result = resetResult {
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
			
			Text(
				"""
				Select the key that the card was programmed with. \
				The key will be reset to the default value (all zeros).
				"""
			)
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
						Image(systemName: "eraser.line.dashed.fill")
							.imageScale(.medium)
						Text("Reset card")
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
	func section_result(_ result: Result<Void, NfcWriter.WriteError>) -> some View {
		
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
				The card has now been reset. \
				Key0 has been set to the default value (all zeros). \
				The card can now be written to again.
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
		resetResult = nil
		
		let input = NfcWriter.ResetInput(
			key0        : selectedKey.keySet.key0.toByteArray(),
			piccDataKey : selectedKey.keySet.piccDataKey.toByteArray(),
			cmacKey     : selectedKey.keySet.cmacKey.toByteArray()
		)
		
		NfcWriter.shared.resetCard(input) { result in
			
			isWriting = false
			switch result {
			case .success(_):
				resetResult = result
				
			case .failure(let error):
				var ignore = false
				if case .scanningTerminated(let reason) = error {
					ignore = reason.isIgnorable() // e.g. user tapped "cancel" button
				}
				if ignore {
					resetResult = nil
				} else {
					resetResult = result
				}
			}
		}
	}
}
