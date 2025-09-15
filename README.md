# DnaCommunicator

DnaCommincator is an iOS framework for communicating with NFC tags of type [NTAG 424 DNA](https://www.nxp.com/products/rfid-nfc/nfc-hf/ntag-for-tags-and-labels/ntag-424-dna-424-dna-tagtamper-advanced-security-and-privacy-for-trusted-iot-applications:NTAG424DNA). This is the same type of card used by the [Bolt Card](https://www.boltcard.org/).



The project was inspired by johnnyb's [NfcDnaKit](https://github.com/johnnyb/nfc-dna-kit). We've modernized that project, fixed several bugs, and added a few helpful features.

If you're looking for an Android equivalent, see the [ntag424-java](https://github.com/johnnyb/ntag424-java) project.


## Installation

Use the [Swift Package Manager](https://www.hackingwithswift.com/books/ios-swiftui/adding-swift-package-dependencies-in-xcode) to add this framework to your Xcode project. Then you'll need to make a few changes in your Xcode project to enable NFC:

- Add the "Near Field Communication Tag Reading" capability to your target
- Add the following to your `Info.plist` file:

```xml
<key>NFCReaderUsageDescription</key>
<string>NFC required to read/write NFC tags</string>
<key>com.apple.developer.nfc.readersession.iso7816.select-identifiers</key>
<array>
    <string>D2760000850101</string>
</array>
```



## Usage

To use DnaCommunicator, you first setup a [NFCTagReaderSession](https://developer.apple.com/documentation/corenfc/nfctagreadersession) and use that to connect to the card. Then you pass the connected session to `DnaCommunicator.init`. Your code might look something like this:



```swift
class NfcWriter: NSObject, NFCTagReaderSessionDelegate {
  
  let queue = DispatchQueue(label: "NfcWriter")
  var session: NFCTagReaderSession? = nil
  
  func start() {
    guard NFCReaderSession.readingAvailable else {
      // NFC capabilities not available on this device
      return
    }

    session = NFCTagReaderSession(pollingOption: .iso14443, delegate: self, queue: queue)
    session?.alertMessage = "Hold your card near the device to program it."
    session?.begin()
  }
  
  func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
    // NFC UI sheet is being displayed by iOS
  }

  func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: any Error) {
    // Handle error here
  }

  func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {

    var properTag: NFCTag? = nil
    for tag in tags {
      if case .iso7816 = tag {
        properTag = tag
        break
      }
    }

    if let properTag {
      Task {
        await connectToTag(properTag)
      }
    } else {
      session.restartPolling()
    }
  }

  private func connectToTag(_ tag: NFCTag) async {

    guard case let .iso7816(isoTag) = tag, let session else {
      return
    }

    do {
      try await session.connect(to: tag)

      let dnaLogger = {(msg: String) -> Void in
        print(msg)
      }
      let dna = DnaCommunicator(tag: isoTag, logger: dnaLogger)
      await authenticate(dna)
			
    } catch {
      // handle error
    }
  }

  private func authenticate(
    _ dna: DnaCommunicator
  ) async {

    let result = await dna.authenticateEV2First(
      keyNum  : .KEY_0,
      keyData : DnaCommunicator.defaultKey
    )

    switch result {
    case .failure(let error):
      // handle error

    case .success(_):
      // you can now program the card
    }
  }
}
```



## Sample Code

A sample Xcode project is included that shows how to:

* Read from the card
* Write/program the card
* Reset the card




https://github.com/user-attachments/assets/38ce9882-dc36-4545-9370-56c4622bbf73




(*Note that you don't need the DnaCommunicator project to read from a NTAG 424 DNA tag. You can just use `NFCNDEFReaderSession` and read it as a normal NDEF tag.*)



## NTAG 424 DNA: Cliff Notes

Before getting started, it's important to have a basic understanding of the hardware. Cliff notes are provided below, with links to dive deeper at the end.



NTAG 424 DNA is an NFC specification. The chipset has AES encryption, and a built-in counter, which allows it to generate dynamic values that change everytime the card is read.



When you simply read the card, it operates as a NFC type 4 tag. Which is a spec that's super common, and supported almost everywhere. Meaning that almost every modern cell phone can read these cards.



For example, if you tap the card to your phone, it might read:

```
foo:bar?picc_data=6fbd71185a71b2fd29a5aa7b7006a8a3&cmac=f135ae3682f25dd7
```

And if you tap it again, the output will be slightly different:

```
foo:bar?picc_data=4a9a3bf97f22a10f3f840251adbcdb91&cmac=441aa8d8d01f5e4b
```



### Programming the card

In order to write to the card, you first have to "login". This is done using the `authenticateEV2First` command. And in order to login, you have to know the master key (otherwise known as key0) that's currently on the card. All cards come with a default key0, which is all zeros:

```
default_key_0 = 00000000000000000000000000000000
```

> A quick word of caution - there's no way to read the value of the keys on the card. So if you change key zero, and forget what it is, you've just locked yourself out of the card. Which means you just bricked it.

Once you're logged in, you can program the card however you want.

The card has storage for 5 different keys, and a 256 bytes NDEF file. So the basic idea is:

##### **Keys:**

You'll change some keys to random values that you generate.

```
key_1 = 96aa8e8e921e82eda6a8e881472791b7
key_2 = 1e92ba49427e8e3e937c202182f047f3
```

##### NDEF template string:

You'll write a "template" string. Where the zeros will get dynamically replaced everytime the card is read.

```
foo:bar?picc_data=00000000000000000000000000000000&cmac=000
0000000000000
```

Note that your template can either be a URL, or plain text. See the sample Xcode project for details.

##### NDEF template settings:

And then you add the template settings, so the card knows where to place the dynamically generated content.

```
piccOffet = 18
piccKey = key_1
cmacOffset = 56
cmacKey = key_2
```

Once you've setup the code to perform the above, all of this will happen within milliseconds. So you'll just tap the card to the phone, and it will be programmed.



### Reading from the card

Now that the card is programmed, what will happen when you read from it?



As metioned above, when you simply read the card, it operates as a NFC type 4 tag. On iOS, this means you can read it using a `NFCNDEFReaderSession`. And here's what will happen inside the card when you read from it:



```
// First, the card increments its internal counter
counter += 1

// then it generates the "picc" data according
// to the template settings you provided (key_1)
picc = AES.encrypt(
  key = key_1,
  data = "${UID}${counter}${random_bytes}"
).toHex()

// then it generates a "message authentication code"
// using the template settings you provided (key_2)
cmac = AES.cmac(
  key = key_2,
  data = "${header}${UID}${counter}${padding}"
).toHex()

// then it updates the template string,
// and outputs the resulting value
foo:bar?picc_data=6fbd71185a71b2fd29a5aa7b7006a8a3&cmac=f135ae3682f25dd7

// Next time the value will be different,
// because the counter value will be different.
```



### Dive deeper

* [Demystify the Secure Dynamic Message with NTAG 424 DNA NFC tags (Android/Java) Part 1](https://medium.com/@androidcrypto/demystify-the-secure-dynamic-message-with-ntag-424-dna-nfc-tags-android-java-part-1-b947c482913c)
* [Demystify the Secure Dynamic Message with NTAG 424 DNA NFC tags (Android/Java) Part 2](https://medium.com/@androidcrypto/demystify-the-secure-dynamic-message-with-ntag-424-dna-nfc-tags-android-java-part-2-1f8878faa928)
* [Product page](https://www.nxp.com/products/rfid-nfc/nfc-hf/ntag-for-tags-and-labels/ntag-424-dna-424-dna-tagtamper-advanced-security-and-privacy-for-trusted-iot-applications:NTAG424DNA)
* [Specifications PDF](https://www.nxp.com/docs/en/data-sheet/NT4H2421Gx.pdf)





