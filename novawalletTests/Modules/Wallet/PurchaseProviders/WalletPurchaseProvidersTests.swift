import XCTest
@testable import novawallet
import UIKit.UIColor
import SubstrateSdk
import Cuckoo
import Operation_iOS

class WalletRampProvidersTests: XCTestCase {
    let address = "15cfSaBcTxNr8rV59cbhdMNCRagFr3GE6B3zZRsCp4QHHKPu"

    func testPurchaseProviders() throws {
        do {
            try performTransakRampTest(rampActionType: .onRamp)
            try performTransakRampTest(rampActionType: .offRamp)
            try performMercuryoRampTest(rampActionType: .onRamp)
            try performMercuryoRampTest(rampActionType: .offRamp)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func performTransakRampTest(rampActionType: RampActionType) throws {
        // given
        let providers = JSON.dictionaryValue(["transak": JSON.dictionaryValue([:])])

        let asset = ChainModelGenerator.generateAssetWithId(
            0,
            symbol: "DOT",
            buyProviders: providers,
            sellProviders: providers
        )

        let chain = ChainModelGenerator.generateChain(assets: [asset], addressPrefix: 0)
        let chainAsset = ChainAsset(chain: chain, asset: asset)

        let accountId = try address.toAccountId()

        let host = TransakProvider.baseUrlString
        let network = chain.name.lowercased()
        let referrerDomain = "io.novafoundation.novawallet.dev"

        let expectedURL = switch rampActionType {
        case .offRamp:
            "\(host)?network=\(network)&cryptoCurrencyCode=\(asset.symbol)&referrerDomain=\(referrerDomain)&productsAvailed=SELL"
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        case .onRamp:
            "\(host)?network=\(network)&cryptoCurrencyCode=\(asset.symbol)&referrerDomain=\(referrerDomain)&walletAddress=\(address)&disableWalletAddressForm=true&productsAvailed=BUY"
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        }

        let provider = switch rampActionType {
        case .offRamp:
            TransakProvider()
        case .onRamp:
            TransakProvider()
        }

        let operationQueue = OperationQueue()

        // when
        let expectation = XCTestExpectation()

        let actions = provider.buildRampActions(for: chainAsset, accountId: accountId)
            .filter { $0.type == rampActionType }

        let urlWrapper = actions[0].urlFactory.createURLWrapper()

        operationQueue.addOperations(urlWrapper.allOperations, waitUntilFinished: true)

        do {
            let url = try urlWrapper.targetOperation.extractNoCancellableResultData()
            // then
            XCTAssertEqual(url.absoluteString, expectedURL)
            expectation.fulfill()

            wait(for: [expectation], timeout: Constants.defaultExpectationDuration)
        } catch {
            XCTFail("Can't build ramp provider URL: \(error)")
        }
    }

    func performMercuryoRampTest(rampActionType: RampActionType) throws {
        // given
        let providers = JSON.dictionaryValue(["mercuryo": JSON.dictionaryValue([:])])

        let asset = ChainModelGenerator.generateAssetWithId(
            0,
            symbol: "DOT",
            buyProviders: providers,
            sellProviders: providers
        )

        let chain = ChainModelGenerator.generateChain(assets: [asset], addressPrefix: 0)
        let chainAsset = ChainAsset(chain: chain, asset: asset)

        let accountId = try address.toAccountId()
        let redirectUrl = ApplicationConfig.shared.purchaseRedirect

        // A fixed secret keeps the expected signature independent of the key the build was given.
        let providerConfig = MercuryoProvider.Configuration(
            baseUrl: MercuryoProvider.Configuration.debug.baseUrl,
            widgetId: MercuryoProvider.Configuration.debug.widgetId,
            secret: "mercuryo-unit-test-secret"
        )
        let host = providerConfig.baseUrl
        let widgetId = providerConfig.widgetId

        let merchantTransactionId = "90A0270B-BB0A-4A91-BB82-AD09EE73EB78"

        let ipAddressProvider = MockIPAddressProviderProtocol()
        stub(ipAddressProvider) { stub in
            stub.createIPAddressOperation().then {
                .createWithResult("8.8.8.8")
            }
        }

        let merchantIdFactory = MockMerchantTransactionIdFactoryProtocol()
        stub(merchantIdFactory) { stub in
            stub.createTransactionId().then {
                merchantTransactionId
            }
        }

        // SHA-512 of address + secret + IP address + merchant transaction id
        let signature = "v2:9d89ccea5dae8e1077eed92833fab8893e22e1573612eba747d58e44f564e0dae451fdb86424dffe43c970b094d89a51fcddfd27702cb3a2170f020dc9d45e18"

        // swiftlint:disable next long_string
        let expectedURL = switch rampActionType {
        case .offRamp:
            "\(host)?currency=\(asset.symbol)&type=sell&address=\(address)&widget_id=\(widgetId)&merchant_transaction_id=\(merchantTransactionId)&signature=\(signature)&hide_refund_address=true&refund_address=\(address)"
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        case .onRamp:
            "\(host)?currency=\(asset.symbol)&type=buy&address=\(address)&widget_id=\(widgetId)&merchant_transaction_id=\(merchantTransactionId)&signature=\(signature)&return_url=\(redirectUrl)"
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        }

        let provider = switch rampActionType {
        case .offRamp:
            MercuryoProvider(
                configuration: providerConfig,
                merchantIdFactory: merchantIdFactory,
                ipAddressProvider: ipAddressProvider
            )
        case .onRamp:
            MercuryoProvider(
                configuration: providerConfig,
                merchantIdFactory: merchantIdFactory,
                ipAddressProvider: ipAddressProvider
            )
            .with(callbackUrl: redirectUrl)
        }

        let operationQueue = OperationQueue()

        // when
        let expectation = XCTestExpectation()

        let actions = provider.buildRampActions(for: chainAsset, accountId: accountId)
            .filter { $0.type == rampActionType }

        var urlWrapper = actions[0].urlFactory.createURLWrapper()

        operationQueue.addOperations(urlWrapper.allOperations, waitUntilFinished: true)

        do {
            let url = try urlWrapper.targetOperation.extractNoCancellableResultData()
            // then
            XCTAssertEqual(url.absoluteString, expectedURL)
            expectation.fulfill()

            wait(for: [expectation], timeout: Constants.defaultExpectationDuration)
        } catch {
            XCTFail("Can't build ramp provider URL: \(error)")
        }
    }
}
