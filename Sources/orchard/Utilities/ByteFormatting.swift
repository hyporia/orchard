import Foundation

func formatBytes(_ bytes: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useAll]
    formatter.countStyle = .file
    return formatter.string(fromByteCount: bytes)
}
