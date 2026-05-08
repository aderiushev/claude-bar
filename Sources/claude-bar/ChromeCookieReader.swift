import Foundation
import CommonCrypto
import Security
import SQLite3

enum ChromeCookieError: Error {
    case cookieFileNotFound
    case keychainDenied(OSStatus)
    case keychainEmpty
    case sqliteOpen
    case sqlitePrepare
    case decryptFailed
}

enum ChromeCookieReader {
    static func claudeCookies() throws -> [HTTPCookie] {
        let src = try resolveCookieFile()
        Log.info("cookie file: \(src.path)")
        let tmp = FileManager.default.temporaryDirectory
            .appending(path: "claude-bar-chrome-\(UUID().uuidString).db")
        try FileManager.default.copyItem(at: src, to: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let pwd = try keychainPassword()
        Log.info("keychain pwd len=\(pwd.count)")
        let key = try derivedKey(from: pwd)
        Log.info("derived key len=\(key.count)")

        var db: OpaquePointer?
        guard sqlite3_open_v2(tmp.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            throw ChromeCookieError.sqliteOpen
        }
        defer { sqlite3_close(db) }

        let schemaVersion = readSchemaVersion(db: db)
        let stripHostHashPrefix = schemaVersion >= 24
        Log.info("schema version=\(schemaVersion) stripHostHashPrefix=\(stripHostHashPrefix)")

        let sql = """
            SELECT host_key, name, value, encrypted_value, path, expires_utc, is_secure
            FROM cookies
            WHERE host_key = 'claude.ai' OR host_key LIKE '%.claude.ai'
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw ChromeCookieError.sqlitePrepare
        }
        defer { sqlite3_finalize(stmt) }

        var cookies: [HTTPCookie] = []
        var rowsSeen = 0
        var decryptOk = 0
        var decryptFail = 0
        while sqlite3_step(stmt) == SQLITE_ROW {
            rowsSeen += 1
            guard
                let hostC = sqlite3_column_text(stmt, 0),
                let nameC = sqlite3_column_text(stmt, 1)
            else { continue }
            let host = String(cString: hostC)
            let name = String(cString: nameC)

            var value: String? = nil
            if let plain = sqlite3_column_text(stmt, 2) {
                let s = String(cString: plain)
                if !s.isEmpty { value = s }
            }
            if value == nil {
                let bytes = sqlite3_column_bytes(stmt, 3)
                if bytes > 0, let blob = sqlite3_column_blob(stmt, 3) {
                    let data = Data(bytes: blob, count: Int(bytes))
                    let prefix = data.prefix(3).map { String(format: "%02x", $0) }.joined()
                    if let dec = decryptV10(data, key: key, stripHostHashPrefix: stripHostHashPrefix) {
                        value = dec
                        decryptOk += 1
                    } else {
                        decryptFail += 1
                        if decryptFail <= 3 {
                            Log.info("decrypt fail: name=\(name) host=\(host) bytes=\(bytes) prefix=\(prefix)")
                        }
                    }
                }
            }
            guard let resolved = value else { continue }

            let path = sqlite3_column_text(stmt, 4).map { String(cString: $0) } ?? "/"
            let expiresMicros = sqlite3_column_int64(stmt, 5)
            let isSecure = sqlite3_column_int(stmt, 6) != 0

            var props: [HTTPCookiePropertyKey: Any] = [
                .domain: host,
                .name: name,
                .value: resolved,
                .path: path,
            ]
            if isSecure { props[.secure] = "TRUE" }
            if expiresMicros > 0, let date = unixDate(fromChromeMicros: expiresMicros) {
                props[.expires] = date
            }
            if let cookie = HTTPCookie(properties: props) {
                cookies.append(cookie)
            }
        }
        Log.info("rows=\(rowsSeen) decryptOk=\(decryptOk) decryptFail=\(decryptFail) cookies=\(cookies.count)")
        return cookies
    }

    private static func resolveCookieFile() throws -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidates = [
            home.appending(path: "Library/Application Support/Google/Chrome/Default/Network/Cookies"),
            home.appending(path: "Library/Application Support/Google/Chrome/Default/Cookies"),
        ]
        for c in candidates where FileManager.default.fileExists(atPath: c.path) {
            return c
        }
        throw ChromeCookieError.cookieFileNotFound
    }

    private static func keychainPassword() throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Chrome Safe Storage",
            kSecAttrAccount as String: "Chrome",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var out: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &out)
        Log.info("keychain SecItemCopyMatching status=\(status)")
        guard status == errSecSuccess else {
            throw ChromeCookieError.keychainDenied(status)
        }
        guard let data = out as? Data, let s = String(data: data, encoding: .utf8) else {
            throw ChromeCookieError.keychainEmpty
        }
        return s
    }

    private static func derivedKey(from password: String) throws -> Data {
        let pwdData = Data(password.utf8)
        let saltData = Data("saltysalt".utf8)
        var key = Data(count: 16)
        let status = key.withUnsafeMutableBytes { keyPtr -> Int32 in
            pwdData.withUnsafeBytes { pwdBytes -> Int32 in
                saltData.withUnsafeBytes { saltBytes -> Int32 in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        pwdBytes.baseAddress!.assumingMemoryBound(to: CChar.self),
                        pwdData.count,
                        saltBytes.baseAddress!.assumingMemoryBound(to: UInt8.self),
                        saltData.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA1),
                        1003,
                        keyPtr.baseAddress!.assumingMemoryBound(to: UInt8.self),
                        16
                    )
                }
            }
        }
        guard status == kCCSuccess else { throw ChromeCookieError.decryptFailed }
        return key
    }

    private static func decryptV10(_ data: Data, key: Data, stripHostHashPrefix: Bool) -> String? {
        guard data.count > 3, data.prefix(3) == Data("v10".utf8) else { return nil }
        let ciphertext = data.subdata(in: 3..<data.count)
        let iv = Data(repeating: 0x20, count: 16)
        let bufferLen = ciphertext.count + kCCBlockSizeAES128
        var plaintext = Data(count: bufferLen)
        var bytesOut = 0

        let status = plaintext.withUnsafeMutableBytes { ptOut -> Int32 in
            ciphertext.withUnsafeBytes { ctIn -> Int32 in
                iv.withUnsafeBytes { ivBytes -> Int32 in
                    key.withUnsafeBytes { keyBytes -> Int32 in
                        CCCrypt(
                            CCOperation(kCCDecrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyBytes.baseAddress,
                            key.count,
                            ivBytes.baseAddress,
                            ctIn.baseAddress,
                            ciphertext.count,
                            ptOut.baseAddress,
                            bufferLen,
                            &bytesOut
                        )
                    }
                }
            }
        }
        guard status == kCCSuccess else { return nil }
        plaintext.removeSubrange(bytesOut..<bufferLen)
        if stripHostHashPrefix, plaintext.count > 32 {
            plaintext.removeFirst(32)
        }
        return String(data: plaintext, encoding: .utf8)
    }

    private static func readSchemaVersion(db: OpaquePointer?) -> Int {
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, "SELECT value FROM meta WHERE key='version'", -1, &stmt, nil) == SQLITE_OK else {
            return 0
        }
        guard sqlite3_step(stmt) == SQLITE_ROW, let cstr = sqlite3_column_text(stmt, 0) else {
            return 0
        }
        return Int(String(cString: cstr)) ?? 0
    }

    private static func unixDate(fromChromeMicros micros: Int64) -> Date? {
        let chromeEpochOffsetSeconds: Int64 = 11_644_473_600
        let unixSeconds = micros / 1_000_000 - chromeEpochOffsetSeconds
        guard unixSeconds > 0 else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(unixSeconds))
    }
}
