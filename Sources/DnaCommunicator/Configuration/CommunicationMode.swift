/**
 * DnaCommunicator
 * For communicating with NFC tags of type NTAG 424 DNA.
 * https://github.com/ACINQ/DnaCommunicator
 *
 * Special thanks to Jonathan Bartlett.
 */

import Foundation

public enum CommuncationMode: UInt8 {
	case PLAIN = 0
	case MAC   = 1
	case FULL  = 3
}
