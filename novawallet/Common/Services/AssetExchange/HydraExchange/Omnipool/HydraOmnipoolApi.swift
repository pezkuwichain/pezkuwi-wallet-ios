import Foundation
import HydraMathApi
import BigInt

enum HydraOmnipoolApiError: Error {
    case runtimeError(String)
}

enum HydraOmnipoolApi {
    struct Params {
        let assetInState: HydraOmnipool.AssetState
        let assetOutState: HydraOmnipool.AssetState
        let assetInBalance: BigUInt
        let assetOutBalance: BigUInt
        let assetFee: BigUInt
        let protocolFee: BigUInt
        let maxSlipFee: BigUInt
    }

    static func calculateOutGivenIn(
        for params: Params,
        amountIn: BigUInt
    ) throws -> BigUInt {
        let assetFee = try BigRational.permillPercent(
            of: params.assetFee
        ).decimalOrError().stringWithPointSeparator

        let protocolFee = try BigRational.permillPercent(
            of: params.protocolFee
        ).decimalOrError().stringWithPointSeparator

        let maxSlipFee = try BigRational.permillPercent(
            of: params.maxSlipFee
        ).decimalOrError().stringWithPointSeparator

        let result = HydraOmnipoolMath.omnipoolCalculateOutGivenIn(
            String(params.assetInBalance),
            String(params.assetInState.hubReserve),
            String(params.assetInState.shares),
            String(params.assetOutBalance),
            String(params.assetOutState.hubReserve),
            String(params.assetOutState.shares),
            String(amountIn),
            assetFee,
            protocolFee,
            maxSlipFee
        )

        guard let amount = BigUInt(result.toString()) else {
            throw HydraOmnipoolApiError.runtimeError("out given in calc failed")
        }

        return amount
    }

    static func calculateInGivenOut(
        for params: Params,
        amountOut: BigUInt
    ) throws -> BigUInt {
        let assetFee = try BigRational.permillPercent(
            of: params.assetFee
        ).decimalOrError().stringWithPointSeparator

        let protocolFee = try BigRational.permillPercent(
            of: params.protocolFee
        ).decimalOrError().stringWithPointSeparator

        let maxSlipFee = try BigRational.permillPercent(
            of: params.maxSlipFee
        ).decimalOrError().stringWithPointSeparator

        let result = HydraOmnipoolMath.omnipoolCalculateInGivenOut(
            String(params.assetInBalance),
            String(params.assetInState.hubReserve),
            String(params.assetInState.shares),
            String(params.assetOutBalance),
            String(params.assetOutState.hubReserve),
            String(params.assetOutState.shares),
            String(amountOut),
            assetFee,
            protocolFee,
            maxSlipFee
        )

        guard let amount = BigUInt(result.toString()) else {
            throw HydraOmnipoolApiError.runtimeError("in given out calc failed")
        }

        return amount
    }
}
