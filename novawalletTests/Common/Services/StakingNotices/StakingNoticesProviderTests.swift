import XCTest
@testable import novawallet

final class StakingNoticesProviderTests: XCTestCase {
    private var tempCacheURL: URL!

    override func setUpWithError() throws {
        let tempDir = FileManager.default.temporaryDirectory
        tempCacheURL = tempDir.appendingPathComponent("staking_notices_test_\(UUID().uuidString).json")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempCacheURL)
    }

    func testEmptyOnFirstLaunch() {
        let provider = StakingNoticesProvider(
            url: URL(string: "https://example.com/x.json")!,
            cacheURL: tempCacheURL
        )
        XCTAssertTrue(provider.allNotices.isEmpty)
    }

    func testLoadsCachedFileOnInit() throws {
        let json = """
        [{
          "chainId": "70255b4d28de0fc4e1a193d7e175ad1ccef431598211c55538f1018651a0344e",
          "severity": "info",
          "shortText": "Test",
          "longText": "Test long"
        }]
        """.data(using: .utf8)!
        try json.write(to: tempCacheURL)

        let provider = StakingNoticesProvider(
            url: URL(string: "https://example.com/x.json")!,
            cacheURL: tempCacheURL
        )

        // Drain the queue so init's loadFromDisk completes.
        let exp = expectation(description: "load")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) { exp.fulfill() }
        wait(for: [exp], timeout: 1)

        XCTAssertEqual(provider.allNotices.count, 1)
    }

    func testMalformedEntryDoesNotBreakBatch() {
        let json = """
        [
          {"chainId": "bad-entry-missing-fields"},
          {
            "chainId": "70255b4d28de0fc4e1a193d7e175ad1ccef431598211c55538f1018651a0344e",
            "severity": "info",
            "shortText": "Test",
            "longText": "Test long"
          }
        ]
        """.data(using: .utf8)!
        try? json.write(to: tempCacheURL)

        let provider = StakingNoticesProvider(
            url: URL(string: "https://example.com/x.json")!,
            cacheURL: tempCacheURL
        )
        let exp = expectation(description: "load")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) { exp.fulfill() }
        wait(for: [exp], timeout: 1)

        XCTAssertEqual(provider.allNotices.count, 1)
    }
}
