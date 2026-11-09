import SwiftUI

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
                    model.expression = "A~B~C~D~ + A~B~C~D"
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
                Text("Karnaugh map")
                    .font(.title2.bold())
                Spacer()
                Text("Σm(\(result.minterms.map(String.init).joined(separator: ", ")))")
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            KarnaughMapView(map: result.map)

            VStack(alignment: .leading, spacing: 8) {
                Label("Simplified sum of products", systemImage: "arrow.triangle.branch")
                    .font(.headline)
                Text(result.simplifiedExpression)
                    .font(.system(.title3, design: .monospaced).weight(.semibold))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Negation is written as ~variable.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(18)
            .background(Color.accentColor.opacity(0.09), in: RoundedRectangle(cornerRadius: 14))
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
    @Published var expression = "A~B~C~D~ + A~B~C~D" {
        didSet {
            let uppercase = expression.uppercased()
            if expression != uppercase {
                expression = uppercase
            }
        }
    }
    @Published var analysis: KarnaughAnalysis?
    @Published var errorMessage: String?

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
