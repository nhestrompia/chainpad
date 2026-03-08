import Foundation

public struct DexTokenProfile: Sendable {
    public var chain: Chain
    public var name: String?
    public var symbol: String?
    public var priceUSD: Double?
    public var liquidityUSD: Double?
    public var marketCapUSD: Double?
    public var ageDays: Int?
    public var pairURL: String?
    public var imageURL: String?
    public var websiteURL: String?
    public var twitterURL: String?
    public var telegramURL: String?

    public init(
        chain: Chain,
        name: String?,
        symbol: String?,
        priceUSD: Double?,
        liquidityUSD: Double?,
        marketCapUSD: Double?,
        ageDays: Int?,
        pairURL: String?,
        imageURL: String?,
        websiteURL: String?,
        twitterURL: String?,
        telegramURL: String?
    ) {
        self.chain = chain
        self.name = name
        self.symbol = symbol
        self.priceUSD = priceUSD
        self.liquidityUSD = liquidityUSD
        self.marketCapUSD = marketCapUSD
        self.ageDays = ageDays
        self.pairURL = pairURL
        self.imageURL = imageURL
        self.websiteURL = websiteURL
        self.twitterURL = twitterURL
        self.telegramURL = telegramURL
    }
}

public actor DexScreenerClient {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func fetchTokenProfile(address: String) async -> DexTokenProfile? {
        guard let url = URL(string: "https://api.dexscreener.com/latest/dex/tokens/\(address)") else {
            return nil
        }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 8
            let (data, response) = try await session.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                return nil
            }

            let payload = try JSONDecoder().decode(DexScreenerResponse.self, from: data)
            guard let pairs = payload.pairs, !pairs.isEmpty else {
                return nil
            }

            let selectedPair = preferredPair(from: pairs)
            let createdAt = selectedPair?.pairCreatedAt.map {
                Date(timeIntervalSince1970: TimeInterval($0) / 1000)
            }

            let ageDays = createdAt.map {
                Calendar.current.dateComponents([.day], from: $0, to: Date()).day
            } ?? nil

            return DexTokenProfile(
                chain: Chain.fromDex(selectedPair?.chainId ?? pairs[0].chainId),
                name: selectedPair?.baseToken.name ?? pairs[0].baseToken.name,
                symbol: selectedPair?.baseToken.symbol ?? pairs[0].baseToken.symbol,
                priceUSD: Double(selectedPair?.priceUsd ?? ""),
                liquidityUSD: selectedPair?.liquidity?.usd,
                marketCapUSD: selectedPair?.marketCap,
                ageDays: ageDays,
                pairURL: selectedPair?.url,
                imageURL: firstImageURL(in: pairs),
                websiteURL: firstWebsiteURL(in: pairs),
                twitterURL: firstTwitterURL(in: pairs),
                telegramURL: firstTelegramURL(in: pairs)
            )
        } catch {
            return nil
        }
    }

    public func fetchPairURL(tokenAddress: String) async -> String? {
        await fetchTokenProfile(address: tokenAddress)?.pairURL
    }

    private func preferredPair(from pairs: [DexPair]) -> DexPair? {
        pairs.max { lhs, rhs in
            let left = lhs.liquidity?.usd ?? 0
            let right = rhs.liquidity?.usd ?? 0
            return left < right
        }
    }

    private func firstImageURL(in pairs: [DexPair]) -> String? {
        pairs.lazy.compactMap { pair in
            let value = pair.info?.imageUrl?.trimmingCharacters(in: .whitespacesAndNewlines)
            return (value?.isEmpty == false) ? value : nil
        }.first
    }

    private func firstWebsiteURL(in pairs: [DexPair]) -> String? {
        pairs.lazy.compactMap { pair in
            pair.info?.websites?.first(where: {
                guard let url = $0.url?.trimmingCharacters(in: .whitespacesAndNewlines) else { return false }
                return !url.isEmpty
            })?.url
        }.first
    }

    private func firstTwitterURL(in pairs: [DexPair]) -> String? {
        for pair in pairs {
            if let socials = pair.info?.socials {
                if let byType = socials.first(where: { social in
                    let type = social.type?.lowercased() ?? ""
                    return type.contains("twitter") || type == "x"
                })?.url, !byType.isEmpty {
                    return byType
                }

                if let byHost = socials.first(where: { social in
                    guard let rawURL = social.url, let host = URL(string: rawURL)?.host?.lowercased() else { return false }
                    return host.contains("twitter.com") || host == "x.com" || host.hasSuffix(".x.com")
                })?.url, !byHost.isEmpty {
                    return byHost
                }
            }
        }

        return nil
    }

    private func firstTelegramURL(in pairs: [DexPair]) -> String? {
        for pair in pairs {
            if let socials = pair.info?.socials {
                if let byType = socials.first(where: {
                    ($0.type?.lowercased() ?? "").contains("telegram")
                })?.url {
                    if !byType.isEmpty {
                        return byType
                    }
                }

                if let byHost = socials.first(where: { social in
                    guard let rawURL = social.url, let host = URL(string: rawURL)?.host?.lowercased() else { return false }
                    return host == "t.me" || host.hasSuffix(".t.me") || host.contains("telegram.me")
                })?.url, !byHost.isEmpty {
                    return byHost
                }
            }
        }

        return nil
    }
}

public actor EVMRPCClient {
    private let session: URLSession
    private let rpcEndpoints: [Chain: URL]

    public init(session: URLSession = .shared, rpcEndpoints: [Chain: URL] = EVMRPCClient.defaultEndpoints) {
        self.session = session
        self.rpcEndpoints = rpcEndpoints
    }

    public func chainWithTransaction(hash: String) async -> Chain? {
        for chain in Chain.allCases where chain.isEVM {
            if await transactionExists(hash: hash, chain: chain) {
                return chain
            }
        }

        return nil
    }

    public func transactionExists(hash: String, chain: Chain) async -> Bool {
        guard let response = await call(method: "eth_getTransactionByHash", params: [hash], chain: chain) else {
            return false
        }

        if case .dictionary(let object) = response, object["hash"] != nil {
            return true
        }

        return false
    }

    public func contractCode(address: String, chain: Chain) async -> String? {
        guard let response = await call(method: "eth_getCode", params: [address, "latest"], chain: chain) else {
            return nil
        }

        if case .string(let code) = response {
            return code
        }

        return nil
    }

    public func nativeBalance(address: String, chain: Chain) async -> Double? {
        guard let response = await call(method: "eth_getBalance", params: [address, "latest"], chain: chain) else {
            return nil
        }

        guard case .string(let hex) = response else {
            return nil
        }

        guard let wei = UInt64(hex.replacingOccurrences(of: "0x", with: ""), radix: 16) else {
            return nil
        }

        return Double(wei) / 1_000_000_000_000_000_000
    }

    private func call(method: String, params: [Any], chain: Chain) async -> JSONValue? {
        guard let endpoint = rpcEndpoints[chain] else {
            return nil
        }

        struct RPCRequest: Encodable {
            let jsonrpc = "2.0"
            let id = 1
            let method: String
            let params: [JSONValue]
        }

        let encodedParams = params.map(JSONValue.any)
        let payload = RPCRequest(method: method, params: encodedParams)

        do {
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 8
            request.httpBody = try JSONEncoder().encode(payload)

            let (data, response) = try await session.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                return nil
            }

            let rpcResponse = try JSONDecoder().decode(RPCResponse.self, from: data)
            return rpcResponse.result
        } catch {
            return nil
        }
    }

    public static let defaultEndpoints: [Chain: URL] = [
        .ethereum: URL(string: "https://cloudflare-eth.com")!,
        .base: URL(string: "https://mainnet.base.org")!,
        .bsc: URL(string: "https://bsc-dataseed.binance.org")!,
        .arbitrum: URL(string: "https://arb1.arbitrum.io/rpc")!,
        .polygon: URL(string: "https://polygon-rpc.com")!,
    ]
}

public actor SolanaRPCClient {
    private let session: URLSession
    private let endpoint: URL
    private let tokenProgramID = "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA".lowercased()
    private let token2022ProgramID = "TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb".lowercased()

    public init(session: URLSession = .shared, endpoint: URL = URL(string: "https://api.mainnet-beta.solana.com")!) {
        self.session = session
        self.endpoint = endpoint
    }

    public func addressLooksValid(_ address: String) async -> Bool {
        guard let result = await call(method: "getBalance", params: [.string(address)]) else {
            return false
        }

        if case .dictionary = result {
            return true
        }

        return false
    }

    public func balance(address: String) async -> Double? {
        guard let result = await call(method: "getBalance", params: [.string(address)]) else {
            return nil
        }

        guard case .dictionary(let object) = result,
              case .number(let lamports)? = object["value"] else {
            return nil
        }

        return lamports / 1_000_000_000
    }

    public func transactionExists(signature: String) async -> Bool {
        let params: [JSONValue] = [
            .string(signature),
            .dictionary(["maxSupportedTransactionVersion": .number(0)]),
        ]

        guard let result = await call(method: "getTransaction", params: params) else {
            return false
        }

        if case .null = result {
            return false
        }

        return true
    }

    public func tokenProgramOwnedAccountExists(address: String) async -> Bool {
        let params: [JSONValue] = [
            .string(address),
            .dictionary(["encoding": .string("jsonParsed")]),
        ]

        guard let result = await call(method: "getAccountInfo", params: params) else {
            return false
        }

        guard case .dictionary(let response) = result,
              case .dictionary(let value)? = response["value"],
              case .string(let owner)? = value["owner"] else {
            return false
        }

        let normalized = owner.lowercased()
        return normalized == tokenProgramID || normalized == token2022ProgramID
    }

    private func call(method: String, params: [JSONValue]) async -> JSONValue? {
        struct RequestBody: Encodable {
            let jsonrpc = "2.0"
            let id = 1
            let method: String
            let params: [JSONValue]
        }

        do {
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 8
            request.httpBody = try JSONEncoder().encode(RequestBody(method: method, params: params))

            let (data, response) = try await session.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                return nil
            }

            let parsed = try JSONDecoder().decode(RPCResponse.self, from: data)
            return parsed.result
        } catch {
            return nil
        }
    }
}

private struct DexScreenerResponse: Decodable {
    var pairs: [DexPair]?
}

private struct DexPair: Decodable {
    var chainId: String
    var url: String?
    var pairCreatedAt: Int?
    var priceUsd: String?
    var marketCap: Double?
    var liquidity: Liquidity?
    var baseToken: DexToken
    var info: DexPairInfo?
}

private struct DexToken: Decodable {
    var symbol: String?
    var name: String?
}

private struct Liquidity: Decodable {
    var usd: Double?
}

private struct DexPairInfo: Decodable {
    var imageUrl: String?
    var websites: [DexPairLink]?
    var socials: [DexPairSocial]?

    private enum CodingKeys: String, CodingKey {
        case imageUrl
        case imageURL
        case icon
        case websites
        case socials
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
            ?? (try container.decodeIfPresent(String.self, forKey: .imageURL))
            ?? (try container.decodeIfPresent(String.self, forKey: .icon))
        websites = try container.decodeIfPresent([DexPairLink].self, forKey: .websites)
        socials = try container.decodeIfPresent([DexPairSocial].self, forKey: .socials)
    }
}

private struct DexPairLink: Decodable {
    var label: String?
    var url: String?
}

private struct DexPairSocial: Decodable {
    var type: String?
    var url: String?
}

private struct RPCResponse: Codable {
    var result: JSONValue?
}

public enum JSONValue: Codable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case array([JSONValue])
    case dictionary([String: JSONValue])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let number = try? container.decode(Double.self) {
            self = .number(number)
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let array = try? container.decode([JSONValue].self) {
            self = .array(array)
        } else if let dictionary = try? container.decode([String: JSONValue].self) {
            self = .dictionary(dictionary)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .string(let string):
            try container.encode(string)
        case .number(let number):
            try container.encode(number)
        case .bool(let bool):
            try container.encode(bool)
        case .array(let array):
            try container.encode(array)
        case .dictionary(let dictionary):
            try container.encode(dictionary)
        case .null:
            try container.encodeNil()
        }
    }

    static func any(_ any: Any) -> JSONValue {
        if let string = any as? String {
            return .string(string)
        }
        if let int = any as? Int {
            return .number(Double(int))
        }
        if let double = any as? Double {
            return .number(double)
        }
        if let bool = any as? Bool {
            return .bool(bool)
        }
        return .null
    }
}

public extension Chain {
    var isEVM: Bool {
        switch self {
        case .ethereum, .base, .bsc, .arbitrum, .polygon:
            return true
        case .solana, .unknown:
            return false
        }
    }

    static func fromDex(_ chainID: String) -> Chain {
        switch chainID.lowercased() {
        case "solana":
            return .solana
        case "ethereum", "eth":
            return .ethereum
        case "base":
            return .base
        case "bsc", "binance":
            return .bsc
        case "arbitrum":
            return .arbitrum
        case "polygon":
            return .polygon
        default:
            return .unknown
        }
    }
}
