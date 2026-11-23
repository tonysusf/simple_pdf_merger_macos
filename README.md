# Simple PDF Merger

Simple PDF Merger is a free, MIT-licensed macOS app for combining PDFs. It uses Apple’s SwiftUI and PDFKit and processes files locally.

## Build and open

You’ll need macOS 14 or later and Xcode or its command-line tools with the macOS 14 SDK or later.

```sh
./build.sh
open "build/Simple PDF Merger.app"
```

The build produces a universal app for Apple silicon and Intel Macs, with an ad hoc signature for local use.

## Merge PDFs

1. Click **Add PDFs** or drag PDFs from Finder into the list.
2. Select a file and use **Move Up** or **Move Down** to set the order.
3. Click **Merge PDFs…** and choose where to save the combined file.

Unlock password-protected PDFs before adding them.

## License

[MIT](LICENSE)
