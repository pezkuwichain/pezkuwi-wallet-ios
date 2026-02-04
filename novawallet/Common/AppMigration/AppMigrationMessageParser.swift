import Foundation

public enum AppMigrationMessageParsingError: Error {
    case invalidURL(URL)
    case expectedQueryParam(String)
    case schemeMismatch(String?)
}

public protocol AppMigrationMessageParsing {
    func parseAction(from url: URL) -> AppMigrationAction?

    func parseMessage(
        for action: AppMigrationAction,
        from url: URL
    ) throws -> AppMigrationMessage
}

public final class AppMigrationMessageParser {
    let localDeepLinkScheme: String
    let queryFactory: AppMigrationQueryFactoryProtocol

    public init(
        localDeepLinkScheme: String,
        queryFactory: AppMigrationQueryFactoryProtocol = AppMigrationDefaultQueryFactory()
    ) {
        self.localDeepLinkScheme = localDeepLinkScheme
        self.queryFactory = queryFactory
    }
}

// MARK: - Private

private extension AppMigrationMessageParser {
    func parseQueryItems(from url: URL) throws -> [URLQueryItem] {
        guard
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let queryItems = components.queryItems,
            !queryItems.isEmpty else {
            throw AppMigrationMessageParsingError.invalidURL(url)
        }

        return queryItems
    }

    func parseQueryItem<T>(
        by queryKey: AppMigrationQueryKey,
        from items: [URLQueryItem],
        using mappingClosure: (String) throws -> T
    ) throws -> T {
        guard
            let item = items.first(where: { $0.name == queryKey.rawValue }),
            let value = item.value else {
            throw AppMigrationMessageParsingError.expectedQueryParam(queryKey.rawValue)
        }

        return try mappingClosure(value)
    }

    func parseQueryItemString(
        by queryKey: AppMigrationQueryKey,
        from items: [URLQueryItem]
    ) throws -> String {
        try parseQueryItem(by: queryKey, from: items, using: { $0 })
    }
}

// MARK: - Start Message Parsing

private extension AppMigrationMessageParser {
    func parseStartDeepLinkMessage(from url: URL) throws -> AppMigrationMessage {
        let queryItems = try parseQueryItems(from: url)
        let scheme = try parseQueryItemString(by: .scheme, from: queryItems)

        return .start(.init(originScheme: scheme))
    }

    func parseStartAppLinkMessage(from url: URL) throws -> AppMigrationMessage {
        let queryItems = try parseQueryItems(from: url)
        let scheme = try parseQueryItemString(by: .scheme, from: queryItems)

        return .start(.init(originScheme: scheme))
    }

    func parseStartMessage(from url: URL) throws -> AppMigrationMessage {
        if url.scheme == localDeepLinkScheme {
            return try parseStartDeepLinkMessage(from: url)
        } else if
            let scheme = url.scheme,
            AppMigrationParams.allowedAppLinkSchemes.contains(scheme) {
            return try parseStartAppLinkMessage(from: url)
        } else {
            throw AppMigrationMessageParsingError.schemeMismatch(url.scheme)
        }
    }
}

// MARK: - Accept Message Parsing

private extension AppMigrationMessageParser {
    func parseAcceptMessage(from url: URL) throws -> AppMigrationMessage {
        guard url.scheme == localDeepLinkScheme else {
            throw AppMigrationMessageParsingError.schemeMismatch(url.scheme)
        }

        let queryItems = try parseQueryItems(from: url)

        let pubKey: AppMigrationKeypair.PublicKey = try parseQueryItem(
            by: .key,
            from: queryItems
        ) { value in
            try queryFactory.data(from: value)
        }

        return .accepted(.init(destinationPublicKey: pubKey))
    }
}

// MARK: - Complete Message Parsing

private extension AppMigrationMessageParser {
    func parseCompleteMessage(from url: URL) throws -> AppMigrationMessage {
        guard url.scheme == localDeepLinkScheme else {
            throw AppMigrationMessageParsingError.schemeMismatch(url.scheme)
        }

        let queryItems = try parseQueryItems(from: url)

        let pubKey: AppMigrationKeypair.PublicKey = try parseQueryItem(
            by: .key,
            from: queryItems
        ) { value in
            try queryFactory.data(from: value)
        }

        let encryptedData: Data = try parseQueryItem(
            by: .encryptedData,
            from: queryItems
        ) { value in
            try queryFactory.data(from: value)
        }

        let complete = AppMigrationMessage.Complete(
            originPublicKey: pubKey,
            encryptedData: encryptedData
        )

        return .complete(complete)
    }
}

// MARK: - Action Extraction

private extension AppMigrationMessageParser {
    func extractRawActionFromAppLink(url: URL) -> String? {
        do {
            let queryItems = try parseQueryItems(from: url)
            return try parseQueryItemString(by: .action, from: queryItems)
        } catch {
            return nil
        }
    }

    func extractRawActionFromDeepLink(url: URL) -> String? {
        url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    func extractRawAction(from url: URL) -> String? {
        if url.scheme == localDeepLinkScheme {
            return extractRawActionFromDeepLink(url: url)
        } else if
            let scheme = url.scheme,
            AppMigrationParams.allowedAppLinkSchemes.contains(scheme) {
            return extractRawActionFromAppLink(url: url)
        } else {
            return nil
        }
    }
}

// MARK: - AppMigrationMessageParsing

extension AppMigrationMessageParser: AppMigrationMessageParsing {
    public func parseAction(from url: URL) -> AppMigrationAction? {
        guard let rawValue = extractRawAction(from: url) else {
            return nil
        }

        return AppMigrationAction(rawValue: rawValue)
    }

    public func parseMessage(
        for action: AppMigrationAction,
        from url: URL
    ) throws -> AppMigrationMessage {
        switch action {
        case .migrate:
            try parseStartMessage(from: url)
        case .migrateAccepted:
            try parseAcceptMessage(from: url)
        case .migrateComplete:
            try parseCompleteMessage(from: url)
        }
    }
}
