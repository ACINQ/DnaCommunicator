/**
 * DnaCommunicator
 * For communicating with NFC tags of type NTAG 424 DNA.
 * https://github.com/ACINQ/DnaCommunicator
 *
 * Special thanks to Jonathan Bartlett.
 */

import Foundation

protocol EncryptionMode {
    func encryptData(message: [UInt8]) -> [UInt8]
    func decryptData(message: [UInt8]) -> [UInt8]
    func generateMac(message: [UInt8]) -> [UInt8]
}
