import Foundation

func formatBytes(_ bytes: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useAll]
    formatter.countStyle = .file
    return formatter.string(fromByteCount: bytes)
}

/// Docker-style uptime label, e.g. "Up 5d 3h", "Up 2h 15m", "Up 4m".
func formatUptime(since start: Date, now: Date = Date()) -> String {
    let seconds = max(0, Int(now.timeIntervalSince(start)))
    let minutes = seconds / 60
    let hours = minutes / 60
    let days = hours / 24
    if days > 0 { return "Up \(days)d \(hours % 24)h" }
    if hours > 0 { return "Up \(hours)h \(minutes % 60)m" }
    if minutes > 0 { return "Up \(minutes)m" }
    return "Up <1m"
}
