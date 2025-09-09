import Foundation
import CoreNFC

extension NFCReaderError {
	
	/// Some "errors" aren't exactly errors. Like if the user taps the "cancel" button.
	/// That's not an error from the user's point-of-view,
	/// and thus doesn't require an error message to be displayed on the screen.
	///
	func isIgnorable() -> Bool {
		
		switch self.code {
		case .readerSessionInvalidationErrorUserCanceled:
			// User tapped "cancel" button
			return true
			
		case .readerSessionInvalidationErrorSessionTimeout:
			// User didn't present a card to the reader.
			// The NFC reader automatically cancelled after 60 seconds.
			return true
			
		case .readerSessionInvalidationErrorSessionTerminatedUnexpectedly:
			// User locked the phone, which automatically terminates the NFC reader.
			return true
			
		default:
			return false
		}
	}
}
