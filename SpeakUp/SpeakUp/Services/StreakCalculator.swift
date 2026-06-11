import Foundation

enum StreakCalculator {
    static func calculate(from dates: [String]) -> (current: Int, longest: Int) {
        let sorted = Array(Set(dates)).sorted(by: >)
        if sorted.isEmpty { return (0, 0) }

        var currentStreak = 1
        for i in 1..<sorted.count {
            guard let d1 = date(from: sorted[i]),
                  let d2 = date(from: sorted[i - 1]) else { continue }
            let diff = Calendar.current.dateComponents([.day], from: d1, to: d2).day ?? 0
            if diff == 1 { currentStreak += 1 }
            else { break }
        }

        var longestStreak = currentStreak
        var tempStreak = 1
        for i in 1..<sorted.count {
            guard let d1 = date(from: sorted[i]),
                  let d2 = date(from: sorted[i - 1]) else { continue }
            let diff = Calendar.current.dateComponents([.day], from: d1, to: d2).day ?? 0
            if diff == 1 {
                tempStreak += 1
                longestStreak = max(longestStreak, tempStreak)
            } else {
                tempStreak = 1
            }
        }

        return (currentStreak, longestStreak)
    }

    private static func date(from string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.date(from: string)
    }
}
