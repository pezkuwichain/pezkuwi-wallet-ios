import Foundation

final class StakingNoticesProvider: StakingNoticesProviding {
    private struct Observer {
        weak var target: AnyObject?
        let callback: () -> Void
    }

    private let url: URL
    private let session: URLSession
    private let cacheURL: URL
    private let queue = DispatchQueue(label: "com.nova.staking-notices", qos: .userInitiated)

    private var notices: [ChainModel.Id: StakingNotice] = [:]
    private var observers: [Observer] = []
    private var inFlight: URLSessionTask?

    init(
        url: URL,
        session: URLSession = .shared,
        cacheURL: URL = StakingNoticesProvider.defaultCacheURL()
    ) {
        self.url = url
        self.session = session
        self.cacheURL = cacheURL
        loadFromDisk()
    }

    static func defaultCacheURL() -> URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("staking_notices.json")
    }

    func notice(for chainId: ChainModel.Id) -> StakingNotice? {
        queue.sync { notices[chainId] }
    }

    var allNotices: [ChainModel.Id: StakingNotice] {
        queue.sync { notices }
    }

    func refresh() {
        queue.async { [weak self] in
            guard let self else { return }
            if self.inFlight != nil { return }
            var request = URLRequest(url: self.url)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            self.inFlight = self.session.dataTask(with: request) { [weak self] data, _, _ in
                guard let self else { return }
                self.queue.async {
                    self.inFlight = nil
                    guard let data else { return }
                    self.applyData(data, persistToDisk: true)
                }
            }
            self.inFlight?.resume()
        }
    }

    func subscribe(_ observer: AnyObject, callback: @escaping () -> Void) {
        queue.async { [weak self] in
            guard let self else { return }
            self.observers.removeAll { $0.target === observer }
            self.observers.append(Observer(target: observer, callback: callback))
        }
    }

    func unsubscribe(_ observer: AnyObject) {
        queue.async { [weak self] in
            self?.observers.removeAll { $0.target === observer || $0.target == nil }
        }
    }

    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: cacheURL) else { return }
        applyData(data, persistToDisk: false)
    }

    /// Parse + commit + notify. Errors on a single entry skip that entry; the rest still apply.
    private func applyData(_ data: Data, persistToDisk: Bool) {
        guard let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return
        }

        var newNotices: [ChainModel.Id: StakingNotice] = [:]
        let decoder = JSONDecoder()
        for entry in array {
            guard let entryData = try? JSONSerialization.data(withJSONObject: entry),
                  let notice = try? decoder.decode(StakingNotice.self, from: entryData) else {
                continue
            }
            newNotices[notice.chainId] = notice
        }

        guard newNotices != notices else { return }
        notices = newNotices

        if persistToDisk {
            try? data.write(to: cacheURL, options: .atomic)
        }

        let snapshot = observers
        DispatchQueue.main.async {
            snapshot.forEach { $0.callback() }
        }
    }
}
