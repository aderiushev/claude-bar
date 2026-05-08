import Foundation

enum FetchError: Error {
    case noChromeCookies
    case missingSessionKey
    case unauthorized
    case noUsageOrg
    case http(Int, String)
    case decode
    case transport(Error)
}

struct FetchResult: Sendable {
    let snapshot: UsageSnapshot
    let orgUUID: String
}

enum UsageFetcher {
    private static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36"
    private static let accountURL = URL(string: "https://claude.ai/api/account")!

    static func fetch() async throws -> FetchResult {
        let cookies: [HTTPCookie]
        do {
            cookies = try ChromeCookieReader.claudeCookies()
        } catch {
            Log.info("chrome cookie read failed: \(error)")
            throw FetchError.noChromeCookies
        }

        let cookieNames = cookies.map { "\($0.name)(\($0.value.count))" }.joined(separator: ",")
        Log.info("chrome cookies: \(cookieNames.isEmpty ? "<none>" : cookieNames)")

        guard cookies.contains(where: { $0.name == "sessionKey" }) else {
            throw FetchError.missingSessionKey
        }

        let (session, cookieHeader) = makeSession(cookies: cookies)

        let accountData = try await get(accountURL, session: session, cookieHeader: cookieHeader, label: "account")
        guard
            let account = try? JSONSerialization.jsonObject(with: accountData) as? [String: Any],
            let memberships = account["memberships"] as? [[String: Any]]
        else { throw FetchError.decode }

        let uuids: [String] = memberships.compactMap {
            ($0["organization"] as? [String: Any])?["uuid"] as? String
        }
        Log.info("account ok, orgs=\(uuids.count)")

        for uuid in uuids {
            let url = URL(string: "https://claude.ai/api/organizations/\(uuid)/usage")!
            do {
                let data = try await get(url, session: session, cookieHeader: cookieHeader, label: "usage[\(uuid.prefix(8))]")
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      json["seven_day"] != nil else { continue }
                return FetchResult(snapshot: mapSnapshot(json), orgUUID: uuid)
            } catch {
                Log.info("usage org \(uuid.prefix(8)) failed: \(error) — trying next")
                continue
            }
        }
        throw FetchError.noUsageOrg
    }

    private static func makeSession(cookies: [HTTPCookie]) -> (URLSession, String) {
        let config = URLSessionConfiguration.ephemeral
        config.httpAdditionalHeaders = [
            "User-Agent": userAgent,
            "Accept": "application/json, text/plain, */*",
            "Accept-Language": "en-US,en;q=0.9",
            "Referer": "https://claude.ai/",
            "anthropic-client-platform": "web_claude_ai",
        ]
        config.httpShouldSetCookies = false
        let cookieHeader = cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
        return (URLSession(configuration: config), cookieHeader)
    }

    private static func get(_ url: URL, session: URLSession, cookieHeader: String, label: String) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw FetchError.decode }
            switch http.statusCode {
            case 200...299:
                return data
            case 401, 403:
                let bodyHint = String(data: data.prefix(120), encoding: .utf8) ?? ""
                Log.info("\(label) -> \(http.statusCode) body=\(bodyHint)")
                throw FetchError.unauthorized
            default:
                let bodyHint = String(data: data.prefix(160), encoding: .utf8) ?? ""
                Log.info("\(label) -> \(http.statusCode) body=\(bodyHint)")
                throw FetchError.http(http.statusCode, bodyHint)
            }
        } catch let error as FetchError {
            throw error
        } catch {
            throw FetchError.transport(error)
        }
    }

    private static func mapSnapshot(_ json: [String: Any]) -> UsageSnapshot {
        let fiveHour = json["five_hour"] as? [String: Any]
        let sevenDay = json["seven_day"] as? [String: Any]
        return UsageSnapshot(
            sessionPct:    pct(fiveHour?["utilization"]),
            weekPct:       pct(sevenDay?["utilization"]),
            sessionResets: parseDate(fiveHour?["resets_at"] as? String),
            weekResets:    parseDate(sevenDay?["resets_at"] as? String)
        )
    }

    private static func pct(_ value: Any?) -> Int? {
        if let d = value as? Double { return Int(d.rounded()) }
        if let i = value as? Int { return i }
        if let n = value as? NSNumber { return Int(n.doubleValue.rounded()) }
        return nil
    }

    nonisolated(unsafe) private static let isoFull: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    nonisolated(unsafe) private static let isoBasic: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static func parseDate(_ s: String?) -> Date? {
        guard let s else { return nil }
        return isoFull.date(from: s) ?? isoBasic.date(from: s)
    }
}
