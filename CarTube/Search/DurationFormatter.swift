//
//  DurationFormatter.swift
//  CarTube
//

import Foundation

public enum DurationFormatter {
    // Strict ISO-8601 duration subset used by the Data API's contentDetails.duration: PT[nH][nM][nS].
    private static let pattern = try! NSRegularExpression(pattern: "^PT(?:(\\d+)H)?(?:(\\d+)M)?(?:(\\d+)S)?$")

    public static func display(_ iso8601: String?) -> String? {
        guard let iso8601, !iso8601.isEmpty else { return nil }

        let range = NSRange(iso8601.startIndex..<iso8601.endIndex, in: iso8601)
        guard let match = pattern.firstMatch(in: iso8601, range: range) else { return nil }

        let hours = intValue(match, group: 1, in: iso8601)
        let minutes = intValue(match, group: 2, in: iso8601)
        let seconds = intValue(match, group: 3, in: iso8601)

        guard hours != nil || minutes != nil || seconds != nil else { return nil }

        if let hours {
            return String(format: "%d:%02d:%02d", hours, minutes ?? 0, seconds ?? 0)
        }
        return String(format: "%d:%02d", minutes ?? 0, seconds ?? 0)
    }

    private static func intValue(_ match: NSTextCheckingResult, group: Int, in string: String) -> Int? {
        guard let range = Range(match.range(at: group), in: string) else { return nil }
        return Int(string[range])
    }
}
