import Foundation

final class StakingNoticesProvider: BaseSyncService, StakingNoticesProviding {
    private let url: URL
    private let session: URLSession
    private let cacheURL: URL

    private let noticesState = Observable<[ChainModel.Id: StakingNotice]>(state: [:])
    // inFlight is always accessed while mutex is held (performSyncUp and stopSyncUp
    // are both invoked by BaseSyncService while holding mutex).
    private var inFlight: URLSessionTask?

    init(
        url: URL,
        session: URLSession = .shared,
        cacheURL: URL = StakingNoticesProvider.defaultCacheURL(),
        logger: LoggerProtocol = Logger.shared
    ) {
        self.url = url
        self.session = session
        self.cacheURL = cacheURL
        super.init(logger: logger)
        loadFromDisk()
    }

    static func defaultCacheURL() -> URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("staking_notices.json")
    }

    // MARK: - StakingNoticesProviding

    func notice(for chainId: ChainModel.Id) -> StakingNotice? {
        mutex.lock()
        defer { mutex.unlock() }
        return noticesState.state[chainId]
    }

    var allNotices: [ChainModel.Id: StakingNotice] {
        mutex.lock()
        defer { mutex.unlock() }
        return noticesState.state
    }

    func refresh() {
        if !getIsActive() { setup() }
        syncUp()
    }

    func subscribe(_ observer: AnyObject, callback: @escaping () -> Void) {
        mutex.lock()
        defer { mutex.unlock() }
        // addObserver with queue: .main → notifications dispatched async to main queue.
        noticesState.addObserver(with: observer, queue: .main) { _, _ in
            callback()
        }
    }

    func unsubscribe(_ observer: AnyObject) {
        mutex.lock()
        defer { mutex.unlock() }
        noticesState.removeObserver(by: observer)
    }

    // MARK: - BaseSyncService

    // Called by BaseSyncService while mutex is already held — do NOT re-lock mutex here.
    override func performSyncUp() {
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let task = session.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }
            if let error {
                self.clearAndComplete(error)
                return
            }
            if let http = response as? HTTPURLResponse, !(200 ..< 300).contains(http.statusCode) {
                self.clearAndComplete(StakingNoticesProviderError.httpStatus(http.statusCode))
                return
            }
            guard let data else {
                self.clearAndComplete(StakingNoticesProviderError.emptyResponse)
                return
            }
            self.applyAndPersist(data)
            self.clearAndComplete(nil)
        }

        // mutex is already held by caller; store directly.
        inFlight = task
        task.resume()
    }

    // Called by BaseSyncService while mutex is already held — do NOT re-lock mutex here.
    override func stopSyncUp() {
        let task = inFlight
        inFlight = nil
        task?.cancel()
    }

    deinit {
        inFlight?.cancel()
    }

    // MARK: - Private

    private func clearAndComplete(_ error: Error?) {
        mutex.lock()
        inFlight = nil
        mutex.unlock()
        complete(error)
    }

    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: cacheURL) else { return }
        applyAndPersist(data, persistToDisk: false)
    }

    /// Parse + commit + optionally persist. Errors on individual entries skip that entry.
    ///
    /// `applyAndPersist` acquires `mutex` internally (it is NOT called while mutex is held,
    /// except via `loadFromDisk` during `init`, at which point no other thread can reach `self`).
    /// When `noticesState.state` is assigned, `Observable<T>` calls `dispatchInQueueWhenPossible`
    /// which async-dispatches to `.main` — so the observer closures run after mutex is released.
    private func applyAndPersist(_ data: Data, persistToDisk: Bool = true) {
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

        mutex.lock()
        let stateChanged = (newNotices != noticesState.state)
        if stateChanged {
            // Safe to assign under mutex: notificiation closures are async-dispatched to .main
            // by dispatchInQueueWhenPossible, so they don't run until after unlock.
            noticesState.state = newNotices
        }
        mutex.unlock()

        if stateChanged, persistToDisk {
            try? data.write(to: cacheURL, options: .atomic)
        }
    }
}

enum StakingNoticesProviderError: Error {
    case httpStatus(Int)
    case emptyResponse
}

#if F_DEV
    extension StakingNoticesProvider {
        /// Inject hardcoded notices for visual testing without a real network fetch.
        /// Caller responsibility: call from the main thread.
        func injectStubForTesting(_ stub: [ChainModel.Id: StakingNotice]) {
            mutex.lock()
            let changed = (stub != noticesState.state)
            if changed {
                noticesState.state = stub
            }
            mutex.unlock()
        }
    }
#endif
