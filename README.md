# Karnaugh Maps

A native macOS SwiftUI app that creates Karnaugh maps and minimum sum-of-products expressions for Boolean functions with one to five variables.

## Build and run

Requirements: macOS 27 and the Swift compiler included with the macOS Command Line Tools.

```sh
./build-app.sh
open build/KarnaughMaps.app
```

The script compiles the Swift sources directly into an `.app` bundle and generates a custom multi-resolution app icon featuring a friendly AND gate. It does not require an Xcode project, Xcode, or XCTest.

## Expression syntax

- Enter one to five unique, single-letter variables in the variable field. They are always capitalized, and their order defines the minterm bit order.
- Use `+` for OR and adjacent variables (or `·`) for AND.
- Negate a variable with `~A`, `A~`, or a combining overline: `A̅`. For keyboard entry, enable the macOS **Unicode Hex Input** input source, type `A`, then hold Option and type `0305` (the Unicode combining overline). The combining tilde `Ã` is also accepted.
- An output assignment such as `Y = ...` is optional. The constants `0` and `1` are supported.

For example, with variables `A, B, C, D`, the function `Y = A~B~C~D~ + A~B~C~D` produces minterms 0 and 1 and simplifies to `~A · ~B · ~C`.

The map uses a clean, ruled-grid layout with complemented-variable overbars and Gray-code row and column assignments, splitting variables between the two axes. Switch between the Karnaugh map and the gate-level circuit using the segmented view selector. The circuit offers three styles:

- **SOP** shows the minimized sum-of-products using NOT, AND, and OR gates.
- **NAND-only** converts that same minimized expression into an equivalent network of NAND gates. Tied NAND inputs provide inversions.
- **XOR-aware** detects affine parity functions and displays an XOR/XNOR gate when possible; other functions fall back to the equivalent SOP drawing.

Simplification uses Quine–McCluskey prime implicants and an exact cover search.
