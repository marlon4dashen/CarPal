import Foundation

struct ELM327Parser: Sendable {
    nonisolated func responseBytes(_ response: String) -> [UInt8] {
        response.components(separatedBy: .newlines).flatMap(bytes(in:))
    }

    nonisolated func payload(for mode: UInt8, pid: UInt8, in response: String) -> [UInt8]? {
        payloads(for: mode, pid: pid, in: response).first
    }

    nonisolated func supportedPIDs(
        base: UInt8,
        requestMode: UInt8 = 0x01,
        response: String
    ) -> Set<UInt8> {
        var supported = Set<UInt8>()
        for payload in payloads(for: requestMode, pid: base, in: response) where payload.count >= 4 {
            for bit in 0..<32 where payload[bit / 8] & (1 << (7 - bit % 8)) != 0 {
                supported.insert(base + UInt8(bit + 1))
            }
        }
        return supported
    }

    nonisolated func vehicleInformationStrings(pid: UInt8, response: String) -> [String] {
        var records: [[UInt8]] = []
        var current: [UInt8] = []

        for line in response.components(separatedBy: .newlines) {
            let lineBytes = bytes(in: line)
            if let marker = lineBytes.indices.first(where: { index in
                lineBytes[index] == 0x49
                    && lineBytes.indices.contains(index + 1)
                    && lineBytes[index + 1] == pid
            }) {
                if !current.isEmpty {
                    records.append(current)
                }
                current = Array(lineBytes.dropFirst(marker + 2))
                if current.first.map({ $0 > 0 && $0 < 0x20 }) == true {
                    current.removeFirst()
                }
            } else if !current.isEmpty {
                var continuation = lineBytes
                if continuation.first.map({ (0x21...0x2F).contains($0) }) == true {
                    continuation.removeFirst()
                }
                current.append(contentsOf: continuation)
            }
        }
        if !current.isEmpty {
            records.append(current)
        }

        return records.compactMap { bytes in
            let printable = bytes.prefix { (0x20...0x7E).contains($0) }
            guard !printable.isEmpty else { return nil }
            return String(bytes: printable, encoding: .ascii)?
                .trimmingCharacters(in: .whitespacesAndNewlines.union(.controlCharacters))
        }.filter { !$0.isEmpty }
    }

    nonisolated func troubleCodes(from response: String) -> [DiagnosticTroubleCode] {
        var codes: [DiagnosticTroubleCode] = []
        for payload in modePayloads(responseMode: 0x43, in: response) {
            var index = 0
            while index + 1 < payload.count {
                let high = payload[index]
                let low = payload[index + 1]
                guard high != 0 || low != 0 else { break }

                let families = ["P", "C", "B", "U"]
                let family = families[Int(high >> 6)]
                let value = (UInt16(high & 0x3F) << 8) | UInt16(low)
                let code = String(format: "%@%04X", family, value)
                if !codes.contains(where: { $0.code == code }) {
                    codes.append(
                        DiagnosticTroubleCode(
                            code: code,
                            summary: Self.summary(for: code)
                        )
                    )
                }
                index += 2
            }
        }
        return codes
    }

    nonisolated private func payloads(for mode: UInt8, pid: UInt8, in response: String) -> [[UInt8]] {
        modePayloads(responseMode: mode + 0x40, pid: pid, in: response)
    }

    nonisolated private func modePayloads(responseMode: UInt8, pid: UInt8? = nil, in response: String) -> [[UInt8]] {
        response.components(separatedBy: .newlines).compactMap { line in
            let bytes = bytes(in: line)
            guard let marker = bytes.indices.first(where: { index in
                bytes[index] == responseMode
                    && (pid == nil || (bytes.indices.contains(index + 1) && bytes[index + 1] == pid))
            }) else {
                return nil
            }
            return Array(bytes.dropFirst(marker + (pid == nil ? 1 : 2)))
        }
    }

    nonisolated private func bytes(in line: String) -> [UInt8] {
        let tokens = line.split { $0.isWhitespace || $0 == ":" }
        var bytes: [UInt8] = []
        for token in tokens {
            guard token.allSatisfy(\.isHexDigit) else { continue }
            if token.count == 2, let byte = UInt8(token, radix: 16) {
                bytes.append(byte)
            } else if token.count > 2, token.count.isMultiple(of: 2) {
                bytes.append(contentsOf: bytePairs(in: token))
            } else if token.count > 3 {
                let withoutStandardCANID = token.dropFirst(3)
                if withoutStandardCANID.count.isMultiple(of: 2) {
                    bytes.append(contentsOf: bytePairs(in: withoutStandardCANID))
                }
            }
        }
        return bytes
    }

    nonisolated private func bytePairs(in token: Substring) -> [UInt8] {
        stride(from: 0, to: token.count, by: 2).compactMap { offset in
            let start = token.index(token.startIndex, offsetBy: offset)
            let end = token.index(start, offsetBy: 2)
            return UInt8(token[start..<end], radix: 16)
        }
    }

    nonisolated private static func summary(for code: String) -> String {
        switch code {
        case "P0171": "System too lean (bank 1)"
        case "P0172": "System too rich (bank 1)"
        case "P0300": "Random or multiple cylinder misfire detected"
        case "P0420": "Catalyst system efficiency below threshold (bank 1)"
        default: "Vehicle-reported diagnostic trouble code"
        }
    }
}
