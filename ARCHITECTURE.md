# Architecture

Karnaugh Maps is a native macOS app for entering Boolean functions with up to five variables, viewing their Karnaugh maps, and exploring simplified logic circuits. It is organized into a SwiftUI presentation layer and a Foundation-based Boolean analysis engine, with the build script assembling both into a standalone `.app` bundle.

The diagram traces the flow from user input through parsing and analysis to the map and circuit views. It also shows how the circuit styles share the same minimized result, and how the icon and app bundle are generated independently at build time.

```mermaid
flowchart TD
    User["User"] --> App["KarnaughMapsApp<br/>SwiftUI window"]

    subgraph UI["Presentation · KarnaughMapsApp.swift"]
        Fields["Variable and function fields"]
        Model["KarnaughViewModel"]
        ViewPicker{"Analysis view"}
        MapView["KarnaughMapView"]
        CircuitStyle{"Circuit style"}
        SOP["SOP gates"]
        NAND["NAND-only gates"]
        XOR["XOR/XNOR gates<br/>or SOP fallback"]
        Fields --> Model
        Model --> ViewPicker
        ViewPicker -->|"Karnaugh map"| MapView
        ViewPicker -->|"Logic circuit"| CircuitStyle
        CircuitStyle --> SOP
        CircuitStyle --> NAND
        CircuitStyle --> XOR
    end

    App --> Fields

    subgraph Logic["Boolean analysis · KarnaughLogic.swift"]
        Normalize["Normalize variable names"]
        Parse["Parse sum-of-products<br/>~A, A~, A̅"]
        Minterms["Expand expression<br/>to minterms"]
        GrayMap["Build Gray-code<br/>Karnaugh map"]
        Minimize["Quine–McCluskey<br/>prime implicants"]
        Cover["Exact cover search"]
        Terms["Structured Boolean terms"]
        Format["Format simplified<br/>SOP expression"]
        Parity["Detect affine<br/>XOR/XNOR parity"]
        Analysis["KarnaughAnalysis"]

        Normalize --> Parse --> Minterms
        Minterms --> GrayMap --> Analysis
        Minterms --> Minimize --> Cover --> Terms
        Terms --> Format --> Analysis
        Minterms --> Parity --> Analysis
    end

    Model -->|"analyze variables and expression"| Normalize
    Analysis -->|"map and minterms"| MapView
    Analysis -->|"simplified expression"| Model
    Analysis -->|"terms and parity metadata"| CircuitStyle

    subgraph Build["Standalone macOS app build · build-app.sh"]
        IconSource["AppIcon.swift"]
        IconGenerator["AppIconGenerator"]
        Iconset["Multi-resolution iconset"]
        ICNS["AppIcon.icns"]
        Plist["Info.plist"]
        SwiftCompiler["swiftc<br/>SwiftUI + AppKit"]
        Sources["KarnaughLogic.swift<br/>KarnaughMapsApp.swift"]
        Bundle["build/KarnaughMaps.app"]

        IconSource --> IconGenerator --> Iconset -->|"iconutil"| ICNS
        Sources --> SwiftCompiler --> Bundle
        Plist --> Bundle
        ICNS --> Bundle
    end
```

The app is compiled directly with the Swift compiler and macOS SDK; no Xcode project or XCTest target is required. Generated app bundles, icon assets, and intermediate binaries are kept under the ignored `build/` directory.
