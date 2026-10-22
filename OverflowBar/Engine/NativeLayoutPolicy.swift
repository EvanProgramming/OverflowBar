// Copyright (Ice) © 2023–2025 Jordan Baird
// Copyright (Thaw) © 2026 Toni Förster
// Adapted for OverflowBar; GPL-3.0. See THIRD_PARTY_NOTICES.md.
import Foundation

enum NativeLayoutPolicy {
    struct Move: Equatable { let item: String; let target: String; let left: Bool }
    static func isReadyToReapply(selected: Set<String>, resolved: Set<String>, hasDivider: Bool, hasArrow: Bool) -> Bool {
        hasDivider && hasArrow && !selected.isDisjoint(with: resolved)
    }
    static func placementIsVerified(items: [(id: String, frame: CGRect)], divider: CGRect, selected: Set<String>) -> Bool {
        items.allSatisfy { selected.contains($0.id) ? $0.frame.maxX <= divider.minX + 2 : $0.frame.minX >= divider.maxX - 2 }
    }
    static func hiddenPlacementIsVerified(groupHidden: Bool, items: [(id: String, frame: CGRect)], divider: CGRect, selected: Set<String>) -> Bool {
        guard groupHidden, !selected.isEmpty, items.contains(where: { selected.contains($0.id) }) else { return false }
        return placementIsVerified(items: items, divider: MenuBarGroupGeometry.compactBoundaryFrame(from: divider), selected: selected)
    }
    static func desiredOrder(current: [String], selected: [String], divider: String) -> [String] {
        let hidden = current.filter { selected.contains($0) && $0 != divider }
        return hidden + [divider] + current.filter { $0 != divider && !hidden.contains($0) }
    }
    static func moves(current: [String], desired: [String], divider: String = "divider") -> [Move] {
        guard let ci = current.firstIndex(of: divider), let di = desired.firstIndex(of: divider) else { return [] }
        let keep = longestCommonSubsequence(Array(current[..<ci]), Array(desired[..<di]))
            .union(longestCommonSubsequence(Array(current[(ci + 1)...]), Array(desired[(di + 1)...])))
            .union([divider])
        var result: [Move] = []
        for index in desired.indices.reversed() where !keep.contains(desired[index]) {
            if index + 1 < desired.count { result.append(Move(item: desired[index], target: desired[index + 1], left: true)) }
            else if index > 0 { result.append(Move(item: desired[index], target: desired[index - 1], left: false)) }
        }
        return result
    }
    static func longestCommonSubsequence(
        _ a: [String],
        _ b: [String],
        preferredMoveUIDs: Set<String> = []
    ) -> Set<String> {
        let m = a.count
        let n = b.count
        guard m > 0, n > 0 else { return [] }

        struct Score: Comparable {
            let establishedCount: Int
            let totalCount: Int

            static func < (lhs: Self, rhs: Self) -> Bool {
                if lhs.totalCount != rhs.totalCount {
                    return lhs.totalCount < rhs.totalCount
                }
                return lhs.establishedCount < rhs.establishedCount
            }

            func adding(isEstablished: Bool) -> Self {
                Score(
                    establishedCount: establishedCount + (isEstablished ? 1 : 0),
                    totalCount: totalCount + 1
                )
            }
        }

        // Prefer subsequences that preserve the most established items, then
        // the greatest total length. This makes an unmanaged arrival the mover
        // when keeping it would displace an existing item (#885).
        let zero = Score(establishedCount: 0, totalCount: 0)
        var dp = Array(repeating: Array(repeating: zero, count: n + 1), count: m + 1)
        for i in 1 ... m {
            for j in 1 ... n {
                if a[i - 1] == b[j - 1] {
                    dp[i][j] = dp[i - 1][j - 1].adding(
                        isEstablished: !preferredMoveUIDs.contains(a[i - 1])
                    )
                } else {
                    dp[i][j] = max(dp[i - 1][j], dp[i][j - 1])
                }
            }
        }

        var result = Set<String>()
        var i = m
        var j = n
        while i > 0, j > 0 {
            if a[i - 1] == b[j - 1] {
                result.insert(a[i - 1])
                i -= 1; j -= 1
            } else if dp[i - 1][j] > dp[i][j - 1] {
                i -= 1
            } else {
                j -= 1
            }
        }
        return result
    }

}
