import Foundation
import DnaCommunicator

struct PresetTemplate: Hashable {
	let template: Ndef.Template
	let name: String
	
	static var a: PresetTemplate {
		let url = URL(string: "https://phoenix.acinq.co")!
		let template = Ndef.Template(baseUrl: url)!
		return PresetTemplate(template: template, name: "Lnurl")
	}
	
	static var b: PresetTemplate {
		let template = Ndef.Template(baseText: "lno1abcdefghijklmnopqrstuvwxyz")
		return PresetTemplate(template: template, name: "Bolt 12 offer")
	}
	
	static var c: PresetTemplate {
		let template = Ndef.Template(baseText: "₿satoshi@phoenixwallet.me")
		return PresetTemplate(template: template, name: "Lightning address")
	}
	
	static var count: Int {
		return all().count
	}
	
	static func all() -> [PresetTemplate] {
		return [
			PresetTemplate.a,
			PresetTemplate.b,
			PresetTemplate.c
		]
	}
}
