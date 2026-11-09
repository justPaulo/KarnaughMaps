import SwiftUI

private enum CircuitStyle: String, CaseIterable, Identifiable {
    case sop
    case nand
    case xorAware

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sop: return "SOP"
        case .nand: return "NAND-only"
        case .xorAware: return "XOR-aware"
        }
    }
}

@main
struct KarnaughMapsApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 820, minHeight: 700)
        }
        .windowResizability(.contentSize)
    }
}

private struct ContentView: View {
    @StateObject private var model = KarnaughViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                inputCard
                if let errorMessage = model.errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .padding(.horizontal, 4)
                }
                if let analysis = model.analysis {
                    results(analysis)
                }
            }
            .padding(28)
            .frame(maxWidth: 1000, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            model.analyze()
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "square.grid.3x3.square")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 3) {
                Text("Karnaugh Maps")
                    .font(.largeTitle.bold())
                Text("Visualize and simplify Boolean functions")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Function")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 6) {
                Text("Variables")
                    .font(.headline)
                TextField("A, B, C, D, E", text: $model.variables)
                    .textFieldStyle(.roundedBorder)
                Text("Enter 1–5 unique single-letter variables, in map bit order.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Boolean expression")
                    .font(.headline)
                TextEditor(text: $model.expression)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 76)
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
                Text("Use + for OR, adjacent variables or · for AND, and ~A, A~, or A̅ for NOT. On macOS Unicode Hex Input, type A then hold Option and enter 0305 for A̅. An optional output such as Y= is accepted.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button(action: model.analyze) {
                    Label("Generate map and simplify", systemImage: "function")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: [.command])

                Button("Load example") {
                    model.variables = "A, B, C, D"
                    model.expression = "A~B~C~D~ + A~B~C~D + A̅B C̅D"
                    model.analyze()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func results(_ result: KarnaughAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("Analysis")
                    .font(.title2.bold())
                Spacer()
                Text("Σm(\(result.minterms.map(String.init).joined(separator: ", ")))")
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Label("Simplified sum of products", systemImage: "arrow.triangle.branch")
                    .font(.headline)
                Text(result.simplifiedExpressionWithOverlines)
                    .font(.system(.title3, design: .monospaced).weight(.semibold))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Complemented variables are shown with an overline.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(18)
            .background(Color.accentColor.opacity(0.09), in: RoundedRectangle(cornerRadius: 14))

            Picker("Analysis view", selection: $model.showingCircuit) {
                Label("Karnaugh map", systemImage: "square.grid.3x3.square")
                    .tag(false)
                Label("Logic circuit", systemImage: "point.3.connected.trianglepath.dotted")
                    .tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if model.showingCircuit {
                Picker("Circuit style", selection: $model.circuitStyle) {
                    ForEach(CircuitStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }
                .pickerStyle(.segmented)

                CircuitDiagram(
                    variables: result.variables,
                    terms: result.simplifiedTerms,
                    parity: result.parity,
                    style: model.circuitStyle
                )
            } else {
                KarnaughMapView(map: result.map)
            }
        }
    }

}

private final class KarnaughViewModel: ObservableObject {
    @Published var variables = "A, B, C, D" {
        didSet {
            let uppercase = variables.uppercased()
            if variables != uppercase {
                variables = uppercase
            }
        }
    }
    @Published var expression = "A~B~C~D~ + A~B~C~D + A̅B C̅D" {
        didSet {
            let uppercase = expression.uppercased()
            if expression != uppercase {
                expression = uppercase
            }
        }
    }
    @Published var analysis: KarnaughAnalysis?
    @Published var errorMessage: String?
    @Published var showingCircuit = false
    @Published var circuitStyle = CircuitStyle.sop

    func analyze() {
        do {
            analysis = try KarnaughLogic.analyze(variables: variables, expression: expression)
            errorMessage = nil
        } catch {
            analysis = nil
            errorMessage = error.localizedDescription
        }
    }
}

private struct KarnaughMapView: View {
    let map: KarnaughMap

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Color.clear
                        .frame(width: 62, height: 42)
                    ForEach(map.columnCodes.indices, id: \.self) { column in
                        MapAxisLabel(
                            title: assignmentLabel(map.columnCodes[column], variables: map.columnVariables),
                            isRow: false
                        )
                    }
                }

                HStack(spacing: 0) {
                    VStack(spacing: 0) {
                        ForEach(map.rowCodes.indices, id: \.self) { row in
                            MapAxisLabel(
                                title: assignmentLabel(map.rowCodes[row], variables: map.rowVariables),
                                isRow: true
                            )
                        }
                    }

                    Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                        ForEach(map.cells.indices, id: \.self) { row in
                            GridRow {
                                ForEach(map.cells[row].indices, id: \.self) { column in
                                    MapCell(value: map.cells[row][column])
                                }
                            }
                        }
                    }
                    .overlay {
                        Rectangle()
                            .stroke(Color.primary, lineWidth: 1.2)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.primary.opacity(0.16), lineWidth: 1)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Karnaugh map")
    }

    private func assignmentLabel(_ code: Int, variables: [Character]) -> String {
        guard !variables.isEmpty else { return "" }
        return variables.enumerated().map { index, variable in
            let bit = 1 << (variables.count - index - 1)
            let isSet = code & bit != 0
            let symbol = String(variable).uppercased()
            return isSet ? symbol : "\(symbol)\u{0305}"
        }.joined()
    }
}

private struct MapAxisLabel: View {
    let title: String
    let isRow: Bool

    var body: some View {
        Text(title)
            .font(.system(size: 15, weight: .medium, design: .serif))
            .lineLimit(1)
            .minimumScaleFactor(isRow ? 0.7 : 0.65)
            .frame(
                maxWidth: isRow ? nil : .infinity,
                minHeight: isRow ? 48 : 42
            )
            .frame(width: isRow ? 62 : nil)
    }
}

private struct MapCell: View {
    let value: Int

    var body: some View {
        Text(String(value))
            .font(.system(size: 20, weight: .regular, design: .serif))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(Color.white)
            .overlay {
                Rectangle()
                    .stroke(Color.primary.opacity(0.72), lineWidth: 0.65)
            }
            .accessibilityLabel(value == 1 ? "One, included minterm" : "Zero")
    }
}

private struct CircuitDiagram: View {
    let variables: [Character]
    let terms: [BooleanTerm]
    let parity: BooleanParity?
    let style: CircuitStyle

    private let rowSpacing: CGFloat = 94

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(style.title + " circuit")
                .font(.headline)
            Text(styleDescription)
                .font(.caption)
                .foregroundStyle(.secondary)

            Canvas { context, size in
                switch style {
                case .sop:
                    drawSOP(in: &context, size: size)
                case .nand:
                    drawNAND(in: &context, size: size)
                case .xorAware:
                    if let parity {
                        drawParity(parity, in: &context, size: size)
                    } else {
                        drawSOP(in: &context, size: size)
                    }
                }
            }
            .frame(height: diagramHeight)
            .frame(minWidth: 700)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.16), lineWidth: 1)
            }
            .accessibilityLabel("Gate-level logic circuit for the simplified Boolean function")
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var diagramHeight: CGFloat {
        if style == .xorAware, parity != nil {
            return 230
        }
        return max(210, CGFloat(max(terms.count, 1)) * rowSpacing + 76)
    }

    private var styleDescription: String {
        switch style {
        case .sop:
            return "Product terms feed the final OR gate; negated inputs pass through NOT gates."
        case .nand:
            return "Equivalent NAND-only implementation. Tied NAND inputs act as inverters."
        case .xorAware where parity != nil:
            return "The truth table is affine, so this function is implemented as an XOR/XNOR network."
        case .xorAware:
            return "No equivalent XOR/XNOR parity form was found; showing the equivalent SOP circuit."
        }
    }

    private func drawSOP(in context: inout GraphicsContext, size: CGSize) {
        let ink = Color.primary
        let outputX = size.width - 30
        let inputLabelX: CGFloat = 34
        let inputWireX: CGFloat = 59
        let inverterX: CGFloat = 104
        let andX = size.width * 0.48
        let andWidth: CGFloat = 72
        let orX = size.width * 0.76
        let orWidth: CGFloat = 64
        let firstRowY: CGFloat = 54

        guard !terms.isEmpty else {
            drawLabel("0", at: CGPoint(x: inputLabelX, y: firstRowY), in: &context)
            drawWire(from: CGPoint(x: 48, y: firstRowY), to: CGPoint(x: outputX, y: firstRowY), color: ink, in: &context)
            drawLabel("Y", at: CGPoint(x: outputX + 13, y: firstRowY), in: &context)
            return
        }

        if terms.count == 1, terms[0].literals.isEmpty {
            drawLabel("1", at: CGPoint(x: inputLabelX, y: firstRowY), in: &context)
            drawWire(from: CGPoint(x: 48, y: firstRowY), to: CGPoint(x: outputX, y: firstRowY), color: ink, in: &context)
            drawLabel("Y", at: CGPoint(x: outputX + 13, y: firstRowY), in: &context)
            return
        }

        let rowYs = terms.indices.map { firstRowY + CGFloat($0) * rowSpacing }
        let orTop = max(24, rowYs[0] - 33)
        let orBottom = rowYs[rowYs.count - 1] + 33
        let orCenter = (orTop + orBottom) / 2
        let orHeight = max(66, orBottom - orTop)

        for (termIndex, term) in terms.enumerated() {
            let rowY = rowYs[termIndex]
            let literalCount = term.literals.count
            let gateHeight = max(42, CGFloat(max(literalCount - 1, 0)) * 16 + 28)
            let inputOffsets: [CGFloat]
            if literalCount <= 1 {
                inputOffsets = [0]
            } else {
                inputOffsets = (0..<literalCount).map {
                    CGFloat($0) * (gateHeight - 16) / CGFloat(literalCount - 1) - (gateHeight - 16) / 2
                }
            }

            for (literalIndex, literal) in term.literals.enumerated() {
                let y = rowY + inputOffsets[literalIndex]
                let variableName = String(literal.variable)
                let inputLabel = literal.isNegated ? "\(variableName)\u{0305}" : variableName
                drawLabel(inputLabel, at: CGPoint(x: inputLabelX, y: y), in: &context)

                if literal.isNegated {
                    let triangleTip = inverterX + 25
                    drawWire(from: CGPoint(x: inputWireX, y: y), to: CGPoint(x: inverterX, y: y), color: ink, in: &context)

                    var inverter = Path()
                    inverter.move(to: CGPoint(x: inverterX, y: y - 10))
                    inverter.addLine(to: CGPoint(x: triangleTip, y: y))
                    inverter.addLine(to: CGPoint(x: inverterX, y: y + 10))
                    inverter.closeSubpath()
                    context.fill(inverter, with: .color(.white))
                    context.stroke(inverter, with: .color(ink), lineWidth: 1.6)

                    let bubbleCenter = CGPoint(x: triangleTip + 5, y: y)
                    let bubble = Path(ellipseIn: CGRect(x: bubbleCenter.x - 3.5, y: y - 3.5, width: 7, height: 7))
                    context.fill(bubble, with: .color(.white))
                    context.stroke(bubble, with: .color(ink), lineWidth: 1.4)
                    drawWire(from: CGPoint(x: triangleTip + 8.5, y: y), to: CGPoint(x: andX, y: y), color: ink, in: &context)
                } else {
                    drawWire(from: CGPoint(x: inputWireX, y: y), to: CGPoint(x: andX, y: y), color: ink, in: &context)
                }
            }

            if literalCount > 1 {
                let gate = andGate(at: CGPoint(x: andX, y: rowY), width: andWidth, height: gateHeight)
                context.fill(gate, with: .color(.white))
                context.stroke(gate, with: .color(ink), lineWidth: 1.8)
                drawLabel(
                    "AND",
                    at: CGPoint(x: andX + andWidth * 0.43, y: rowY),
                    fontSize: 11,
                    in: &context
                )
            }

            let termOutputX = andX + (literalCount > 1 ? andWidth : 0)
            let destinationX = terms.count > 1 ? orX + 12 : outputX
            drawWire(from: CGPoint(x: termOutputX, y: rowY), to: CGPoint(x: destinationX, y: rowY), color: ink, in: &context)
        }

        if terms.count > 1 {
            let gate = orGate(at: CGPoint(x: orX, y: orCenter), width: orWidth, height: orHeight)
            context.fill(gate, with: .color(.white))
            context.stroke(gate, with: .color(ink), lineWidth: 1.8)
            drawLabel("OR", at: CGPoint(x: orX + orWidth * 0.59, y: orCenter), fontSize: 11, in: &context)
            drawWire(
                from: CGPoint(x: orX + orWidth, y: orCenter),
                to: CGPoint(x: outputX, y: orCenter),
                color: ink,
                in: &context
            )
            drawLabel("Y", at: CGPoint(x: outputX + 13, y: orCenter), in: &context)
        } else {
            drawLabel("Y", at: CGPoint(x: outputX + 13, y: rowYs[0]), in: &context)
        }
    }

    private func drawNAND(in context: inout GraphicsContext, size: CGSize) {
        let ink = Color.primary
        let outputX = size.width - 30
        let firstRowY: CGFloat = 54

        guard !terms.isEmpty || terms.contains(where: { $0.literals.isEmpty }) else {
            drawLabel("0", at: CGPoint(x: 34, y: firstRowY), in: &context)
            drawWire(from: CGPoint(x: 48, y: firstRowY), to: CGPoint(x: outputX, y: firstRowY), color: ink, in: &context)
            drawLabel("Y", at: CGPoint(x: outputX + 13, y: firstRowY), in: &context)
            return
        }

        if terms.contains(where: { $0.literals.isEmpty }) {
            drawLabel("1", at: CGPoint(x: 34, y: firstRowY), in: &context)
            drawWire(from: CGPoint(x: 48, y: firstRowY), to: CGPoint(x: outputX, y: firstRowY), color: ink, in: &context)
            drawLabel("Y", at: CGPoint(x: outputX + 13, y: firstRowY), in: &context)
            return
        }

        let rowYs = terms.indices.map { firstRowY + CGFloat($0) * rowSpacing }
        let gateX = size.width * 0.43
        let gateWidth: CGFloat = 64
        let finalX = size.width * 0.76
        let finalWidth: CGFloat = 64
        let finalTop = max(25, rowYs[0] - 25)
        let finalBottom = rowYs[rowYs.count - 1] + 25
        let finalHeight = max(46, finalBottom - finalTop)
        let finalCenter = (finalTop + finalBottom) / 2
        let finalInputYs = evenlySpaced(count: terms.count, center: finalCenter, height: finalHeight - 18)

        for (termIndex, term) in terms.enumerated() {
            let rowY = rowYs[termIndex]
            if term.literals.count == 1 {
                let literal = term.literals[0]
                drawLabel(String(literal.variable), at: CGPoint(x: 34, y: rowY), in: &context)
                let source = CGPoint(x: 51, y: rowY)
                let signal: CGPoint
                if literal.isNegated {
                    signal = drawNANDInverter(
                        at: CGPoint(x: 136, y: rowY),
                        inputStart: source,
                        color: ink,
                        in: &context
                    )
                } else {
                    signal = source
                }

                let branchX = max(86, signal.x + 12)
                drawWire(from: signal, to: CGPoint(x: branchX, y: rowY), color: ink, in: &context)
                for offset: CGFloat in [-7, 7] {
                    let inputY = rowY + offset
                    drawWire(from: CGPoint(x: branchX, y: rowY), to: CGPoint(x: branchX, y: inputY), color: ink, in: &context)
                    drawWire(from: CGPoint(x: branchX, y: inputY), to: CGPoint(x: gateX, y: inputY), color: ink, in: &context)
                }
            } else {
                let inputs: [(literal: BooleanLiteral, y: CGFloat)]
                let height = max(26, CGFloat(term.literals.count - 1) * 14)
                inputs = term.literals.enumerated().map { index, literal in
                    (literal, rowY - height / 2 + CGFloat(index) * height / CGFloat(max(term.literals.count - 1, 1)))
                }

                for input in inputs {
                    let literal = input.literal
                    let y = input.y
                    drawLabel(String(literal.variable), at: CGPoint(x: 34, y: y), in: &context)
                    let source = CGPoint(x: 51, y: y)

                    if literal.isNegated {
                        let inverterOutput = drawNANDInverter(
                            at: CGPoint(x: 136, y: y),
                            inputStart: source,
                            color: ink,
                            in: &context
                        )
                        drawWire(from: inverterOutput, to: CGPoint(x: gateX, y: y), color: ink, in: &context)
                    } else {
                        drawWire(from: source, to: CGPoint(x: gateX, y: y), color: ink, in: &context)
                    }
                }
            }

            let gateHeight = max(42, CGFloat(max(term.literals.count, 2) - 1) * 14 + 24)
            let center = CGPoint(x: gateX, y: rowY)
            let termOutput = drawNANDGate(
                at: center,
                width: gateWidth,
                height: gateHeight,
                label: "NAND",
                color: ink,
                in: &context
            )
            let finalInputY = finalInputYs[termIndex]
            let branchX = finalX - 8 - CGFloat(termIndex) * 4
            drawWire(from: termOutput, to: CGPoint(x: branchX, y: rowY), color: ink, in: &context)
            if terms.count == 1 {
                for offset: CGFloat in [-7, 7] {
                    let inputY = finalInputY + offset
                    drawWire(from: CGPoint(x: branchX, y: rowY), to: CGPoint(x: branchX, y: inputY), color: ink, in: &context)
                    drawWire(from: CGPoint(x: branchX, y: inputY), to: CGPoint(x: finalX, y: inputY), color: ink, in: &context)
                }
            } else {
                drawWire(from: CGPoint(x: branchX, y: rowY), to: CGPoint(x: branchX, y: finalInputY), color: ink, in: &context)
                drawWire(from: CGPoint(x: branchX, y: finalInputY), to: CGPoint(x: finalX, y: finalInputY), color: ink, in: &context)
            }
        }

        let finalOutput = drawNANDGate(
            at: CGPoint(x: finalX, y: finalCenter),
            width: finalWidth,
            height: finalHeight,
            label: "NAND",
            color: ink,
            in: &context
        )
        drawWire(from: finalOutput, to: CGPoint(x: outputX, y: finalCenter), color: ink, in: &context)
        drawLabel("Y", at: CGPoint(x: outputX + 13, y: finalCenter), in: &context)
    }

    private func drawParity(_ parity: BooleanParity, in context: inout GraphicsContext, size: CGSize) {
        let ink = Color.primary
        let outputX = size.width - 30
        let centerY = size.height / 2

        guard !parity.variables.isEmpty else {
            let constant = parity.isNegated ? "1" : "0"
            drawLabel(constant, at: CGPoint(x: 44, y: centerY), in: &context)
            drawWire(from: CGPoint(x: 58, y: centerY), to: CGPoint(x: outputX, y: centerY), color: ink, in: &context)
            drawLabel("Y", at: CGPoint(x: outputX + 13, y: centerY), in: &context)
            return
        }

        let gateX = size.width * 0.46
        let gateWidth: CGFloat = 142
        let gateHeight = max(52, CGFloat(parity.variables.count - 1) * 22 + 36)
        let inputYs = evenlySpaced(count: parity.variables.count, center: centerY, height: gateHeight - 20)
        for (index, variable) in parity.variables.enumerated() {
            let y = inputYs[index]
            drawLabel(String(variable), at: CGPoint(x: 40, y: y), in: &context)
            drawWire(from: CGPoint(x: 55, y: y), to: CGPoint(x: gateX, y: y), color: ink, in: &context)
        }

        let xorPath = orGate(at: CGPoint(x: gateX, y: centerY), width: gateWidth, height: gateHeight)
        context.fill(xorPath, with: .color(.white))
        context.stroke(xorPath, with: .color(ink), lineWidth: 1.8)
        context.stroke(xorRearArc(at: CGPoint(x: gateX, y: centerY), width: gateWidth, height: gateHeight), with: .color(ink), lineWidth: 1.8)
        drawLabel("XOR", at: CGPoint(x: gateX + gateWidth * 0.61, y: centerY), fontSize: 13, in: &context)

        var outputStartX = gateX + gateWidth
        if parity.isNegated {
            let bubble = Path(ellipseIn: CGRect(x: outputStartX - 1, y: centerY - 5, width: 10, height: 10))
            context.fill(bubble, with: .color(.white))
            context.stroke(bubble, with: .color(ink), lineWidth: 1.5)
            outputStartX += 9
        }
        drawWire(from: CGPoint(x: outputStartX, y: centerY), to: CGPoint(x: outputX, y: centerY), color: ink, in: &context)
        drawLabel("Y", at: CGPoint(x: outputX + 13, y: centerY), in: &context)
    }

    private func drawNANDInverter(
        at center: CGPoint,
        inputStart: CGPoint? = nil,
        color: Color,
        in context: inout GraphicsContext
    ) -> CGPoint {
        let width: CGFloat = 34
        let height: CGFloat = 28
        let left = center.x
        if let inputStart {
            let branchX = left - 12
            drawWire(from: inputStart, to: CGPoint(x: branchX, y: center.y), color: color, in: &context)
            drawWire(from: CGPoint(x: branchX, y: center.y - 5), to: CGPoint(x: branchX, y: center.y + 5), color: color, in: &context)
            drawWire(from: CGPoint(x: branchX, y: center.y - 5), to: CGPoint(x: left, y: center.y - 5), color: color, in: &context)
            drawWire(from: CGPoint(x: branchX, y: center.y + 5), to: CGPoint(x: left, y: center.y + 5), color: color, in: &context)
        }
        let body = andGate(at: center, width: width, height: height)
        context.fill(body, with: .color(.white))
        context.stroke(body, with: .color(color), lineWidth: 1.5)
        let outputCenterX = left + width + 4
        let bubble = Path(ellipseIn: CGRect(x: outputCenterX - 4, y: center.y - 4, width: 8, height: 8))
        context.fill(bubble, with: .color(.white))
        context.stroke(bubble, with: .color(color), lineWidth: 1.4)
        return CGPoint(x: outputCenterX + 4, y: center.y)
    }

    private func drawNANDGate(
        at center: CGPoint,
        width: CGFloat,
        height: CGFloat,
        label: String,
        color: Color,
        in context: inout GraphicsContext
    ) -> CGPoint {
        let body = andGate(at: center, width: width, height: height)
        context.fill(body, with: .color(.white))
        context.stroke(body, with: .color(color), lineWidth: 1.8)
        let bubbleCenterX = center.x + width + 5
        let bubble = Path(ellipseIn: CGRect(x: bubbleCenterX - 5, y: center.y - 5, width: 10, height: 10))
        context.fill(bubble, with: .color(.white))
        context.stroke(bubble, with: .color(color), lineWidth: 1.5)
        drawLabel(label, at: CGPoint(x: center.x + width * 0.34, y: center.y), fontSize: 10, in: &context)
        return CGPoint(x: bubbleCenterX + 5, y: center.y)
    }

    private func evenlySpaced(count: Int, center: CGFloat, height: CGFloat) -> [CGFloat] {
        guard count > 1 else { return [center] }
        return (0..<count).map { center - height / 2 + CGFloat($0) * height / CGFloat(count - 1) }
    }

    private func xorRearArc(at center: CGPoint, width: CGFloat, height: CGFloat) -> Path {
        let left = center.x - 12
        let top = center.y - height / 2
        let bottom = center.y + height / 2
        let rear = left + width * 0.24
        var path = Path()
        path.move(to: CGPoint(x: rear, y: top))
        path.addCurve(
            to: CGPoint(x: rear, y: bottom),
            control1: CGPoint(x: left - width * 0.13, y: center.y - height * 0.18),
            control2: CGPoint(x: left - width * 0.13, y: center.y + height * 0.18)
        )
        return path
    }

    private func andGate(at center: CGPoint, width: CGFloat, height: CGFloat) -> Path {
        let left = center.x
        let top = center.y - height / 2
        let bottom = center.y + height / 2
        let arcStart = left + width * 0.46

        var path = Path()
        path.move(to: CGPoint(x: left, y: top))
        path.addLine(to: CGPoint(x: arcStart, y: top))
        path.addCurve(
            to: CGPoint(x: arcStart, y: bottom),
            control1: CGPoint(x: left + width, y: top),
            control2: CGPoint(x: left + width, y: bottom)
        )
        path.addLine(to: CGPoint(x: left, y: bottom))
        path.closeSubpath()
        return path
    }

    private func orGate(at center: CGPoint, width: CGFloat, height: CGFloat) -> Path {
        let left = center.x
        let top = center.y - height / 2
        let bottom = center.y + height / 2
        let rear = left + width * 0.24
        let tip = left + width

        var path = Path()
        path.move(to: CGPoint(x: rear, y: top))
        path.addCurve(
            to: CGPoint(x: rear, y: bottom),
            control1: CGPoint(x: left - width * 0.13, y: center.y - height * 0.18),
            control2: CGPoint(x: left - width * 0.13, y: center.y + height * 0.18)
        )
        path.addCurve(
            to: CGPoint(x: tip, y: center.y),
            control1: CGPoint(x: left + width * 0.54, y: bottom - height * 0.12),
            control2: CGPoint(x: left + width * 0.80, y: center.y + height * 0.18)
        )
        path.addCurve(
            to: CGPoint(x: rear, y: top),
            control1: CGPoint(x: left + width * 0.80, y: center.y - height * 0.18),
            control2: CGPoint(x: left + width * 0.54, y: top + height * 0.12)
        )
        path.closeSubpath()
        return path
    }

    private func drawWire(from start: CGPoint, to end: CGPoint, color: Color, in context: inout GraphicsContext) {
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        context.stroke(path, with: .color(color), lineWidth: 1.6)
    }

    private func drawLabel(
        _ value: String,
        at point: CGPoint,
        fontSize: CGFloat = 14,
        in context: inout GraphicsContext
    ) {
        let text = Text(value)
            .font(.system(size: fontSize, weight: .semibold, design: .monospaced))
            .foregroundColor(.primary)
        context.draw(text, at: point)
    }
}
