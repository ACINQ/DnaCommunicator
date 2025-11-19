import Foundation
import DnaCommunicator

struct PresetTemplate: Hashable {
	let template: BoltCardTemplate
	let name: String
	
	static var a: PresetTemplate {
		let url = URL(string: "https://phoenix.acinq.co")!
		let template = BoltCardTemplate(baseUrl: url)!
		return PresetTemplate(template: template, name: "Lnurl")
	}
	
	static var b: PresetTemplate {
		// Sample offer:
		// lno1zz7q8pjw7qjlm68mtp7e3yvxee4y5xrgjhhyf2fxhlphpckrvevh50u0
		// qggpe298mw935q5gya9avdcw4d9agpcvmhtjtr2tmkrrg64ugzyjxqsz529q
		// en0d25hkqxpsxrgx4s5m6uaygl7q7433r4js30pxml63qm0qqv70lf5pm8c4
		// 9qgxj0mt57pz2w9wfeyp7jy2v6qa2n8354863x67tz4hqrac5v343sr0cl76
		// xhqyzd4k84dcqgfxcve5y7av50w5p97zyut04tdps20dj24agyfw4acg0fpw
		// atudvqqq
		//
		// Raw size: 190 bytes (in binary)
		// Encoded size: 308 bytes ("lno1" prefix + bech32 encoding)
		
		let binaryOffer = Data(fromHex:
			"""
			10bc03864ef025fde8fb587d989186ce6a4a186895ee44a926bfc370e2c3\
			66597a3f8f02101ca8a7db8b1a0288274bd6370eab4bd4070cddd7258d4b\
			dd86346abc4089230202a28a0ccded552f60183030d06ac29bd73a447fc0\
			f56311d6508bc26dff5106de0033cffa681d9f152810693f6ba7822538ae\
			4e481f488a6681d54cf1a54fa89b5e58ab700fb8a32358c06fc7fda35c04\
			136b63d5b802126c333427baca3dd4097c22716faada1829ed92abd4112e\
			af7087a42eeaf8d60000
			"""
		)!
		
		let template = BoltCardTemplate(offer: binaryOffer)
		return PresetTemplate(template: template, name: "Bolt 12 offer")
	}
	
	static var c: PresetTemplate {
		let template = BoltCardTemplate(address: "satoshi@phoenixwallet.me")
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
