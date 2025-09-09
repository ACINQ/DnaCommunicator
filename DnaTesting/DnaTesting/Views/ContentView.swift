import SwiftUI
import OSLog

fileprivate let log = Logger.init(subsystem: "DnaTesting", category: "ContentView")

struct ContentView: View {
	
	enum NavLinkTag: Hashable, CustomStringConvertible {
		case ReadCard
		case WriteCard
		case ResetCard
		
		var description: String { switch self {
			case .ReadCard  : "ReadCard"
			case .WriteCard : "WriteCard"
			case .ResetCard : "ResetCard"
		}}
	}
	
	@StateObject var navCoordinator = NavigationCoordinator()
	
	@ViewBuilder
	var body: some View {
		
		NavigationStack(path: $navCoordinator.path) {
			content()
		}
		.environmentObject(navCoordinator)
	}
	
	@ViewBuilder
	func content() -> some View {
	
		VStack(alignment: HorizontalAlignment.center, spacing: 60) {
			
			VStack(alignment: HorizontalAlignment.center, spacing: 4) {
				Text("DnaCommunicator Demo")
					.font(.title3)
				Text("(for NFC type NTAG 424 DNA)")
					.font(.callout)
					.foregroundStyle(.secondary)
			}
			
			Button {
				navigateTo(.ReadCard)
			} label: {
				Label("Read Card", systemImage: "eyes")
			}
			
			Button {
				navigateTo(.WriteCard)
			} label: {
				Label("Write Card", systemImage: "rectangle.and.pencil.and.ellipsis")
			}
			
			Button {
				navigateTo(.ResetCard)
			} label: {
				Label("Reset Card", systemImage: "eraser.line.dashed")
			}
		}
		.padding()
		.onAppear {
			onAppear()
		}
		.navigationDestination(for: NavLinkTag.self) { tag in
			navLinkView(tag)
		}
	}
	
	@ViewBuilder
	func navLinkView(_ tag: NavLinkTag) -> some View {
		
		switch tag {
		case .ReadCard:
			ReadCardView()
			
		case .WriteCard:
			WriteCardView()
			
		case .ResetCard:
			ResetCardView()
		}
	}
	
	// --------------------------------------------------
	// MARK: Notifications
	// --------------------------------------------------
	
	func onAppear() {
		log.trace(#function)
	}
	
	// --------------------------------------------------
	// MARK: Actions
	// --------------------------------------------------
	
	func navigateTo(_ tag: NavLinkTag) {
		log.trace("navigateTo(\(tag.description))")
		navCoordinator.path.append(tag)
	}
}
