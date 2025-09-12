// This file is a mini version of the SwCrypt project:
// https://github.com/soyersoyer/SwCrypt
//
// Originally we included SwCrypt as a dependency.
// However, we needed the latest commit (from 2 years ago),
// which included fixes for Swift 5. And this commit
// isn't included in the latest release (from 5 years ago).
//
// And this is a big problem for the Swift Package Manager (SPM).
// According to the SPM documentation:
//
// > packages which use commit-based dependency requirements
// > can't be added as dependencies to packages that use version-based
// > dependency requirements
//
// In other words:
// If you want to use this library via a version-based dependency,
// this THIS library is only allowed to use version-based dependencies of its own.
//
// So this mini file is the easiest solution for now.
// The license from SwCrypt is included below:

/**
 * MIT License
 *
 * Copyright (c) 2016 Soyer
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

import Foundation
import CommonCrypto

fileprivate func getFunc<T>(_ from: UnsafeMutableRawPointer, f: String) -> T? {
	let sym = dlsym(from, f)
	guard sym != nil else {
		return nil
	}
	return unsafeBitCast(sym, to: T.self)
}

class MiniSwCrypt {
	
	nonisolated(unsafe)
	fileprivate static let dl = dlopen("/usr/lib/system/libcommonCrypto.dylib", RTLD_NOW)
	
	fileprivate static func makeCCError(_ status: CCCryptorStatus) -> NSError {
		return NSError(domain: "MiniSwCrypt", code: Int(status), userInfo: nil)
	}
	
	class CC {
		
		fileprivate typealias CCCryptorCreateWithModeT = @convention(c)(
			_ op: CCOperation,
			_ mode: CCMode,
			_ alg: CCAlgorithm,
			_ padding: CCPadding,
			_ iv: UnsafeRawPointer?,
			_ key: UnsafeRawPointer, _ keyLength: Int,
			_ tweak: UnsafeRawPointer?, _ tweakLength: Int,
			_ numRounds: Int32,
			_ options: CCModeOptions,
			_ cryptorRef: UnsafeMutablePointer<CCCryptorRef?>
		) -> CCCryptorStatus
		
		fileprivate typealias CCCryptorGetOutputLengthT = @convention(c)(
			_ cryptorRef: CCCryptorRef,
			_ inputLength: size_t,
			_ final: Bool
		) -> size_t
		
		fileprivate typealias CCCryptorUpdateT = @convention(c)(
			_ cryptorRef: CCCryptorRef,
			_ dataIn: UnsafeRawPointer,
			_ dataInLength: Int,
			_ dataOut: UnsafeMutableRawPointer,
			_ dataOutAvailable: Int,
			_ dataOutMoved: UnsafeMutablePointer<Int>
		) -> CCCryptorStatus
		
		fileprivate typealias CCCryptorFinalT = @convention(c)(
			_ cryptorRef: CCCryptorRef,
			_ dataOut: UnsafeMutableRawPointer,
			_ dataOutAvailable: Int,
			_ dataOutMoved: UnsafeMutablePointer<Int>
		) -> CCCryptorStatus
		
		fileprivate typealias CCCryptorReleaseT = @convention(c)(
			_ cryptorRef: CCCryptorRef
		) -> CCCryptorStatus
		
		fileprivate static let CCCryptorCreateWithMode: CCCryptorCreateWithModeT? =
			getFunc(dl!, f: "CCCryptorCreateWithMode")
		fileprivate static let CCCryptorGetOutputLength: CCCryptorGetOutputLengthT? =
			getFunc(dl!, f: "CCCryptorGetOutputLength")
		fileprivate static let CCCryptorUpdate: CCCryptorUpdateT? =
			getFunc(dl!, f: "CCCryptorUpdate")
		fileprivate static let CCCryptorFinal: CCCryptorFinalT? =
			getFunc(dl!, f: "CCCryptorFinal")
		fileprivate static let CCCryptorRelease: CCCryptorReleaseT? =
			getFunc(dl!, f: "CCCryptorRelease")
		
		static func available() -> Bool {
			return CCCryptorCreateWithMode != nil &&
				CCCryptorGetOutputLength != nil &&
				CCCryptorUpdate != nil &&
				CCCryptorFinal != nil &&
				CCCryptorRelease != nil
		}
		
		typealias CCOperation = UInt32
		enum OpMode: CCOperation {
			case encrypt = 0, decrypt
		}
		
		typealias CCMode = UInt32
		enum BlockMode: CCMode {
			case ecb = 1, cbc, cfb, ctr, f8, lrw, ofb, xts, rc4, cfb8
			var needIV: Bool {
				switch self {
				case .cbc, .cfb, .ctr, .ofb, .cfb8: return true
				default: return false
				}
			}
		}
		
		typealias CCAlgorithm = UInt32
		enum Algorithm: CCAlgorithm {
			case aes = 0, des, threeDES, cast, rc4, rc2, blowfish

			var blockSize: Int? {
				switch self {
				case .aes: return 16
				case .des: return 8
				case .threeDES: return 8
				case .cast: return 8
				case .rc2: return 8
				case .blowfish: return 8
				default: return nil
				}
			}
		}

		typealias CCPadding = UInt32
		enum Padding: CCPadding {
			case noPadding = 0, pkcs7Padding
		}
		static func crypt(_ opMode: OpMode, blockMode: BlockMode,
								algorithm: Algorithm, padding: Padding,
								data: Data, key: Data, iv: Data) throws -> Data {
			if blockMode.needIV {
				guard iv.count == algorithm.blockSize else { throw makeCCError(-4300) }
			}

			var cryptor: CCCryptorRef? = nil
			var status = withUnsafePointers(iv, key, { ivBytes, keyBytes in
				return CCCryptorCreateWithMode!(
					opMode.rawValue, blockMode.rawValue,
					algorithm.rawValue, padding.rawValue,
					ivBytes, keyBytes, key.count,
					nil, 0, 0,
					CCModeOptions(), &cryptor)
			})

			guard status == noErr else { throw makeCCError(status) }

			defer { _ = CCCryptorRelease!(cryptor!) }

			let needed = CCCryptorGetOutputLength!(cryptor!, data.count, true)
			var result = Data(count: needed)
			let rescount = result.count
			var updateLen: size_t = 0
			status = withUnsafePointers(data, &result, { dataBytes, resultBytes in
				return CCCryptorUpdate!(
					cryptor!,
					dataBytes, data.count,
					resultBytes, rescount,
					&updateLen)
			})
			guard status == noErr else { throw makeCCError(status) }

			var finalLen: size_t = 0
			status = result.withUnsafeMutableBytes { resultBytes -> OSStatus in
				return CCCryptorFinal!(
					cryptor!,
					resultBytes.baseAddress! + updateLen,
					rescount - updateLen,
					&finalLen)
			}
			guard status == noErr else { throw makeCCError(status) }

			result.count = updateLen + finalLen
			return result
		}
	}
	
	class CMAC {

		fileprivate typealias CCAESCmacT = @convention(c) (
			_ key: UnsafeRawPointer,
			_ data: UnsafeRawPointer, _ dataLen: size_t,
			_ macOut: UnsafeMutableRawPointer
		) -> Void
		fileprivate static let CCAESCmac: CCAESCmacT? = getFunc(dl!, f: "CCAESCmac")
		
		static func available() -> Bool {
			return CCAESCmac != nil
		}
		
		static func AESCMAC(_ data: Data, key: Data) -> Data {
			var result = Data(count: 16)
			withUnsafePointers(key, data, &result, { keyBytes, dataBytes, resultBytes in
				CCAESCmac!(keyBytes,
							dataBytes, data.count,
							resultBytes)
			})
			return result
		}
	}
	
	class CRC {

		fileprivate typealias CNCRCT = @convention(c) (
			_ algorithm: CNcrc,
			_ input: UnsafeRawPointer, _ inputLen: size_t,
			_ result: UnsafeMutablePointer<UInt64>
		) -> CCCryptorStatus
		fileprivate static let CNCRC: CNCRCT? = getFunc(dl!, f: "CNCRC")
		
		static func available() -> Bool {
			return CNCRC != nil
		}
		
		typealias CNcrc = UInt32
		enum Mode: CNcrc {
			case crc8 = 10,
			crc8ICODE = 11,
			crc8ITU = 12,
			crc8ROHC = 13,
			crc8WCDMA = 14,
			crc16 = 20,
			crc16CCITTTrue = 21,
			crc16CCITTFalse = 22,
			crc16USB = 23,
			crc16XMODEM = 24,
			crc16DECTR = 25,
			crc16DECTX = 26,
			crc16ICODE = 27,
			crc16VERIFONE = 28,
			crc16A = 29,
			crc16B = 30,
			crc16Fletcher = 31,
			crc32Adler = 40,
			crc32 = 41,
			crc32CASTAGNOLI = 42,
			crc32BZIP2 = 43,
			crc32MPEG2 = 44,
			crc32POSIX = 45,
			crc32XFER = 46,
			crc64ECMA182 = 60
		}

		static func crc(_ input: Data, mode: Mode) throws -> UInt64 {
			var result: UInt64 = 0
			let status = input.withUnsafeBytes { inputBytes -> OSStatus in
				CNCRC!(
					mode.rawValue,
					inputBytes.baseAddress!, input.count,
					&result)
			}
			guard status == noErr else {
				throw makeCCError(status)
			}
			return result
		}
	}
}

fileprivate func withUnsafePointers<A0, A1, Result>(
	_ arg0: Data,
	_ arg1: Data,
	_ body: (
	UnsafePointer<A0>, UnsafePointer<A1>) throws -> Result
	) rethrows -> Result {
	return try arg0.withUnsafeBytes { p0 -> Result in
		return try arg1.withUnsafeBytes { p1 -> Result in
			return try body(p0.bindMemory(to: A0.self).baseAddress!,
							p1.bindMemory(to: A1.self).baseAddress!)
		}
	}
}

fileprivate func withUnsafePointers<A0, A1, Result>(
	_ arg0: Data,
	_ arg1: inout Data,
	_ body: (
		UnsafePointer<A0>,
		UnsafeMutablePointer<A1>) throws -> Result
	) rethrows -> Result {
	return try arg0.withUnsafeBytes { p0 -> Result in
		return try arg1.withUnsafeMutableBytes { p1 -> Result in
			return try body(p0.bindMemory(to: A0.self).baseAddress!,
							p1.bindMemory(to: A1.self).baseAddress!)
		}
	}
}

fileprivate func withUnsafePointers<A0, A1, A2, Result>(
	_ arg0: Data,
	_ arg1: Data,
	_ arg2: inout Data,
	_ body: (
		UnsafePointer<A0>,
		UnsafePointer<A1>,
		UnsafeMutablePointer<A2>) throws -> Result
	) rethrows -> Result {
	return try arg0.withUnsafeBytes { p0 -> Result in
		return try arg1.withUnsafeBytes { p1 -> Result in
			return try arg2.withUnsafeMutableBytes { p2 -> Result in
				return try body(p0.bindMemory(to: A0.self).baseAddress!,
								p1.bindMemory(to: A1.self).baseAddress!,
								p2.bindMemory(to: A2.self).baseAddress!)
			}
		}
	}
}
