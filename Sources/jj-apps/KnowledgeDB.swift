import Foundation
import SQLite3

// knowledgeC `/app/usage` 的区间结束时间 = app 最近一次结束前台使用的时刻。
// 私有数据库受 TCC 保护，必须授予 Full Disk Access；查询只操作带 WAL 的临时副本。
nonisolated enum KnowledgeDB {
    enum FocusResult: Sendable {
        case ok([String: Int64])
        case denied
        case unavailable(String)
    }

    private static let cocoaEpochOffset: Double = 978_307_200

    private static func sourceURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Knowledge/knowledgeC.db")
    }

    static func lastFocusByBundleId() -> FocusResult {
        let fm = FileManager.default
        let src = sourceURL()
        let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("jj-apps-knowledge-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: tmpDir) }

        do {
            try fm.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        } catch {
            return .unavailable("cannot create temp dir: \(error.localizedDescription)")
        }

        let dbCopy = tmpDir.appendingPathComponent("knowledgeC.db")
        do {
            try fm.copyItem(at: src, to: dbCopy)
        } catch let error as NSError {
            if error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoSuchFileError {
                return .unavailable("knowledgeC.db not found")
            }
            return .denied
        }

        for suffix in ["-wal", "-shm"] {
            try? fm.copyItem(
                at: URL(fileURLWithPath: src.path + suffix),
                to: URL(fileURLWithPath: dbCopy.path + suffix)
            )
        }
        return query(dbCopy)
    }

    private static func query(_ dbCopy: URL) -> FocusResult {
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbCopy.path, &db, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK,
              let db else {
            if let db { sqlite3_close(db) }
            return .unavailable("sqlite open failed")
        }
        defer { sqlite3_close(db) }

        let sql = """
        SELECT ZVALUESTRING, MAX(ZENDDATE)
        FROM ZOBJECT
        WHERE ZSTREAMNAME = '/app/usage' AND ZVALUESTRING IS NOT NULL
        GROUP BY ZVALUESTRING;
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            return .unavailable("sqlite prepare failed")
        }
        defer { sqlite3_finalize(statement) }

        var result: [String: Int64] = [:]
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let value = sqlite3_column_text(statement, 0) else { continue }
            let end = sqlite3_column_double(statement, 1)
            guard end > 0 else { continue }
            result[String(cString: value)] = Int64((end + cocoaEpochOffset) * 1000)
        }
        return .ok(result)
    }
}
