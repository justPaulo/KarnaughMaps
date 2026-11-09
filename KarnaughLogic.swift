import Foundation

struct KarnaughMap {
    let rowVariables: [Character]
    let columnVariables: [Character]
    let rowCodes: [Int]
    let columnCodes: [Int]
    let cells: [[Int]]
    let mintermNumbers: [[Int]]
}

struct KarnaughAnalysis {
    let variables: [Character]
    let minterms: [Int]
    let map: KarnaughMap
    let simplifiedExpression: String
    let simplifiedTerms: [BooleanTerm]
}

struct BooleanLiteral {
    let variable: Character
    let isNegated: Bool
}

struct BooleanTerm {
    let literals: [BooleanLiteral]
}

enum LogicInputError: LocalizedError {
    case invalidVariables(String)
    case emptyExpression
    case invalidExpression(String)

    var errorDescription: String? {
        switch self {
        case .invalidVariables(let message), .invalidExpression(let message):
            return message
        case .emptyExpression:
            return "Enter a Boolean function to analyze."
        }
    }
}

enum KarnaughLogic {
    static func analyze(variables input: String, expression: String) throws -> KarnaughAnalysis {
        let variables = try parseVariables(input)
        let minterms = try parseMinterms(expression, variables: variables)
        let map = makeMap(variables: variables, minterms: minterms)
        let simplifiedTerms = simplify(variables: variables, minterms: minterms)
        let simplifiedExpression = format(simplifiedTerms)

        return KarnaughAnalysis(
            variables: variables,
            minterms: minterms.sorted(),
            map: map,
            simplifiedExpression: simplifiedExpression,
            simplifiedTerms: simplifiedTerms
        )
    }

    private static func parseVariables(_ input: String) throws -> [Character] {
        let values = input
            .split(whereSeparator: { $0 == "," || $0.isWhitespace })
            .map { String($0).uppercased() }

        guard !values.isEmpty else {
            throw LogicInputError.invalidVariables("Enter between 1 and 5 variables, separated by commas.")
        }
        guard values.count <= 5 else {
            throw LogicInputError.invalidVariables("Karnaugh maps support up to 5 variables.")
        }

        var variables: [Character] = []
        for value in values {
            guard value.unicodeScalars.count == 1,
                  let scalar = value.unicodeScalars.first,
                  (65...90).contains(scalar.value) || (97...122).contains(scalar.value)
            else {
                throw LogicInputError.invalidVariables("Use single-letter variables such as A, B, C, D, E.")
            }

            let variable = Character(value)
            guard !variables.contains(variable) else {
                throw LogicInputError.invalidVariables("Variable names must be unique.")
            }
            variables.append(variable)
        }
        return variables
    }

    private static func parseMinterms(_ input: String, variables: [Character]) throws -> [Int] {
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LogicInputError.emptyExpression
        }

        var expression = input
        if let equalsIndex = expression.firstIndex(of: "=") {
            expression = String(expression[expression.index(after: equalsIndex)...])
        }
        expression = expression.uppercased().decomposedStringWithCanonicalMapping

        let alternatives = splitAlternatives(expression)
        guard !alternatives.isEmpty, alternatives.allSatisfy({ !$0.isEmpty }) else {
            throw LogicInputError.invalidExpression("Use non-empty sum terms separated by +.")
        }

        let variableIndices = Dictionary(uniqueKeysWithValues: variables.enumerated().map { ($1, $0) })
        let variableCount = variables.count
        var minterms = Set<Int>()

        for alternative in alternatives {
            let compact = alternative.filter { !$0.properties.isWhitespace && !isProductSeparator($0) }
            if compact.count == 1, compact[0] == "0" {
                continue
            }
            if compact.count == 1, compact[0] == "1" {
                return Array(0..<(1 << variableCount))
            }

            var literals: [(index: Int, negated: Bool)] = []
            var pendingNegation = false
            var canUseSuffixNegation = false

            for scalar in alternative {
                if CharacterSet.whitespacesAndNewlines.contains(scalar) || isProductSeparator(scalar) {
                    canUseSuffixNegation = false
                    continue
                }

                if scalar == "~" || scalar.value == 0x0303 || scalar.value == 0x0305 {
                    if canUseSuffixNegation, !literals.isEmpty {
                        literals[literals.count - 1].negated.toggle()
                    } else {
                        pendingNegation.toggle()
                    }
                    canUseSuffixNegation = false
                    continue
                }

                let character = Character(String(scalar))
                guard let index = variableIndices[character] else {
                    throw LogicInputError.invalidExpression(
                        "Unexpected symbol “\(scalar)”. Use the listed variables, ~ for NOT, and + for OR."
                    )
                }
                literals.append((index, pendingNegation))
                pendingNegation = false
                canUseSuffixNegation = true
            }

            guard !pendingNegation else {
                throw LogicInputError.invalidExpression("A negation marker must be followed by or attached to a variable.")
            }
            guard !literals.isEmpty else {
                throw LogicInputError.invalidExpression("Each sum term must contain a variable or be 0 or 1.")
            }

            var positiveMask = 0
            var negativeMask = 0
            for literal in literals {
                let bit = 1 << (variableCount - 1 - literal.index)
                if literal.negated {
                    negativeMask |= bit
                } else {
                    positiveMask |= bit
                }
            }
            if (positiveMask & negativeMask) != 0 {
                continue
            }

            for minterm in 0..<(1 << variableCount) {
                if (minterm & positiveMask) == positiveMask,
                   (minterm & negativeMask) == 0 {
                    minterms.insert(minterm)
                }
            }
        }
        return minterms.sorted()
    }

    private static func splitAlternatives(_ expression: String) -> [[Unicode.Scalar]] {
        var alternatives: [[Unicode.Scalar]] = [[]]
        for scalar in expression.unicodeScalars {
            if scalar == "+" || scalar == "|" || scalar.value == 0x2228 {
                alternatives.append([])
            } else {
                alternatives[alternatives.count - 1].append(scalar)
            }
        }
        return alternatives
    }

    private static func isProductSeparator(_ scalar: Unicode.Scalar) -> Bool {
        scalar == "*" || scalar == "." || scalar == "&" ||
            scalar.value == 0x00B7 || scalar.value == 0x22C5 || scalar.value == 0x2227
    }

    private static func makeMap(variables: [Character], minterms: [Int]) -> KarnaughMap {
        let rowVariableCount = variables.count / 2
        let columnVariableCount = variables.count - rowVariableCount
        let rowVariables = Array(variables.prefix(rowVariableCount))
        let columnVariables = Array(variables.suffix(columnVariableCount))
        let rowCodes = grayCodes(for: rowVariableCount)
        let columnCodes = grayCodes(for: columnVariableCount)
        let mintermSet = Set(minterms)

        var cells: [[Int]] = []
        var mintermNumbers: [[Int]] = []
        for rowCode in rowCodes {
            var cellRow: [Int] = []
            var mintermRow: [Int] = []
            for columnCode in columnCodes {
                let minterm = (rowCode << columnVariableCount) | columnCode
                cellRow.append(mintermSet.contains(minterm) ? 1 : 0)
                mintermRow.append(minterm)
            }
            cells.append(cellRow)
            mintermNumbers.append(mintermRow)
        }

        return KarnaughMap(
            rowVariables: rowVariables,
            columnVariables: columnVariables,
            rowCodes: rowCodes,
            columnCodes: columnCodes,
            cells: cells,
            mintermNumbers: mintermNumbers
        )
    }

    private static func grayCodes(for bitCount: Int) -> [Int] {
        (0..<(1 << bitCount)).map { $0 ^ ($0 >> 1) }
    }

    private struct Cube: Hashable {
        let pattern: Int
        let mask: Int

        func covers(_ minterm: Int) -> Bool {
            ((pattern ^ minterm) & ~mask) == 0
        }

        func literalCount(variableCount: Int) -> Int {
            variableCount - mask.nonzeroBitCount
        }
    }

    private static func simplify(variables: [Character], minterms: [Int]) -> [BooleanTerm] {
        let variableCount = variables.count
        guard !minterms.isEmpty else { return [] }
        if minterms.count == (1 << variableCount) { return [BooleanTerm(literals: [])] }

        var current = Set(minterms.map { Cube(pattern: $0, mask: 0) })
        var primeImplicants = Set<Cube>()

        while !current.isEmpty {
            let cubes = Array(current)
            var combined = Set<Cube>()
            var used = Set<Cube>()

            for leftIndex in cubes.indices {
                for rightIndex in cubes.indices where rightIndex > leftIndex {
                    let left = cubes[leftIndex]
                    let right = cubes[rightIndex]
                    guard left.mask == right.mask else { continue }
                    let difference = (left.pattern ^ right.pattern) & ~left.mask
                    guard difference.nonzeroBitCount == 1 else { continue }

                    used.insert(left)
                    used.insert(right)
                    combined.insert(Cube(
                        pattern: left.pattern & ~difference,
                        mask: left.mask | difference
                    ))
                }
            }

            primeImplicants.formUnion(current.subtracting(used))
            current = combined
        }

        let implicants = primeImplicants.map { cube in
            (cube: cube, coverage: coverage(of: cube, minterms: minterms))
        }.filter { $0.coverage != 0 }

        let target = (UInt64(1) << UInt64(minterms.count)) - 1
        var bestSelection: [Int]?
        var bestLiteralCount = Int.max

        func search(remaining: UInt64, selected: [Int], literalCount: Int) {
            if remaining == 0 {
                if selected.count < (bestSelection?.count ?? Int.max) ||
                    (selected.count == bestSelection?.count && literalCount < bestLiteralCount) {
                    bestSelection = selected
                    bestLiteralCount = literalCount
                }
                return
            }

            if selected.count >= (bestSelection?.count ?? Int.max) {
                return
            }

            var chosenMintermIndex: Int?
            var fewestOptions = Int.max
            for index in minterms.indices where remaining & (UInt64(1) << UInt64(index)) != 0 {
                let optionCount = implicants.reduce(into: 0) { count, implicant in
                    if implicant.coverage & (UInt64(1) << UInt64(index)) != 0 {
                        count += 1
                    }
                }
                if optionCount < fewestOptions {
                    chosenMintermIndex = index
                    fewestOptions = optionCount
                }
            }
            guard let chosenMintermIndex else { return }

            let bit = UInt64(1) << UInt64(chosenMintermIndex)
            let options = implicants.indices
                .filter { implicants[$0].coverage & bit != 0 }
                .sorted {
                    implicants[$0].cube.literalCount(variableCount: variableCount) <
                        implicants[$1].cube.literalCount(variableCount: variableCount)
                }

            for option in options {
                search(
                    remaining: remaining & ~implicants[option].coverage,
                    selected: selected + [option],
                    literalCount: literalCount +
                        implicants[option].cube.literalCount(variableCount: variableCount)
                )
            }
        }

        search(remaining: target, selected: [], literalCount: 0)
        guard let bestSelection else { return [] }

        return bestSelection.map { index -> BooleanTerm in
            let cube = implicants[index].cube
            let literals = variables.enumerated().compactMap { variableIndex, variable -> BooleanLiteral? in
                let bit = 1 << (variableCount - 1 - variableIndex)
                guard cube.mask & bit == 0 else { return nil }
                return BooleanLiteral(variable: variable, isNegated: cube.pattern & bit == 0)
            }
            return BooleanTerm(literals: literals)
        }
    }

    private static func format(_ terms: [BooleanTerm]) -> String {
        guard !terms.isEmpty else { return "0" }
        if terms.contains(where: { $0.literals.isEmpty }) { return "1" }

        return terms.map { term in
            term.literals.map { literal in
                literal.isNegated ? "~\(literal.variable)" : String(literal.variable)
            }
            .joined(separator: " · ")
        }
        .sorted()
        .joined(separator: " + ")
    }

    private static func coverage(of cube: Cube, minterms: [Int]) -> UInt64 {
        minterms.enumerated().reduce(into: UInt64(0)) { result, item in
            if cube.covers(item.element) {
                result |= UInt64(1) << UInt64(item.offset)
            }
        }
    }
}
