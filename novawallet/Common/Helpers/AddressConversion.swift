import Foundation
import NovaCrypto

enum ChainFormat {
    case ethereum
    case tron
    case substrate(_ prefix: UInt16, legacyPrefix: UInt16? = nil)
}

enum TronConstants {
    // Tron mainnet address version/prefix byte, prepended to the 20-byte account id before
    // Base58Check encoding. This is a fixed, publicly-documented Tron protocol constant (not
    // something specific to this fork), the same value used by TronGrid/TronWeb/java-tron.
    static let addressVersionByte: UInt8 = 0x41
}

extension ChainFormat {
    static var defaultSubstrateFormat: ChainFormat {
        .substrate(SubstrateConstants.genericAddressPrefix, legacyPrefix: nil)
    }

    static var multichainDisplayFormat: ChainFormat {
        .substrate(SubstrateConstants.multichainDisplayPrefix, legacyPrefix: nil)
    }
}

extension AccountId {
    func toAddress(using conversion: ChainFormat) throws -> AccountAddress {
        switch conversion {
        case .ethereum:
            toHex(includePrefix: true)
        case .tron:
            Base58Check.encode(payload: self, versionByte: TronConstants.addressVersionByte)
        case let .substrate(prefix, _):
            try SS58AddressFactory().address(
                fromAccountId: self,
                type: prefix
            )
        }
    }

    func toAddressWithDefaultConversion() throws -> AccountAddress {
        let conversion: ChainFormat = if count == SubstrateConstants.ethereumAddressLength {
            .ethereum
        } else if count == SubstrateConstants.accountIdLength {
            .multichainDisplayFormat
        } else {
            throw AccountAddressConversionError.invalidChainAddress
        }

        return try toAddress(using: conversion)
    }
}

enum AccountAddressConversionError: Error {
    case invalidEthereumAddress
    case invalidTronAddress
    case invalidChainAddress
}

extension AccountAddress {
    private func extractEthereumAccountId() throws -> AccountId {
        let accountId = try AccountId(hexString: self)

        guard accountId.count == SubstrateConstants.ethereumAddressLength else {
            throw AccountAddressConversionError.invalidEthereumAddress
        }

        return accountId
    }

    private func extractTronAccountId() throws -> AccountId {
        let (versionByte, payload) = try Base58Check.decode(self)

        guard
            versionByte == TronConstants.addressVersionByte,
            payload.count == SubstrateConstants.ethereumAddressLength else {
            throw AccountAddressConversionError.invalidTronAddress
        }

        return payload
    }

    func toAccountId(using conversion: ChainFormat) throws -> AccountId {
        switch conversion {
        case .ethereum:
            return try extractEthereumAccountId()
        case .tron:
            return try extractTronAccountId()
        case let .substrate(prefix, legacyPrefix):
            let factory = SS58AddressFactory()
            let type = try factory.type(fromAddress: self).uint16Value

            let correspondingPrefix = if let legacyPrefix, legacyPrefix == type {
                legacyPrefix
            } else {
                prefix
            }

            return try factory.accountId(
                fromAddress: self,
                type: correspondingPrefix
            )
        }
    }

    func toAccountId() throws -> AccountId {
        if hasPrefix("0x") {
            return try extractEthereumAccountId()
        } else if let tronAccountId = try? extractTronAccountId() {
            // Guarded by Base58Check's own 4-byte double-SHA256 checksum plus the 0x41 version
            // byte check, so this cannot false-positive on a legitimate SS58 (blake2-checksummed)
            // substrate address - falls through to the SS58 branch below on any mismatch.
            return tronAccountId
        } else {
            let addressFactory = SS58AddressFactory()
            let type = try addressFactory.type(fromAddress: self).uint16Value
            return try addressFactory.accountId(fromAddress: self, type: type)
        }
    }

    func toChainAccountIdOrSubstrateGeneric(
        using conversion: ChainFormat
    ) throws -> AccountId {
        switch conversion {
        case .ethereum:
            return try extractEthereumAccountId()
        case .tron:
            return try extractTronAccountId()
        case let .substrate(prefix, legacyPrefix):
            let addressFactory = SS58AddressFactory()
            let type = try addressFactory.type(fromAddress: self).uint16Value

            guard
                type == legacyPrefix
                || type == prefix
                || type == SNAddressType.genericSubstrate.rawValue
            else {
                throw AccountAddressConversionError.invalidChainAddress
            }

            return try addressFactory.accountId(fromAddress: self, type: type)
        }
    }

    func toSubstrateAccountId(using prefix: UInt16? = nil) throws -> AccountId {
        let factory = SS58AddressFactory()

        let type: UInt16

        if let prefix = prefix {
            type = prefix
        } else {
            type = try factory.type(fromAddress: self).uint16Value
        }

        return try factory.accountId(fromAddress: self, type: type)
    }

    func toEthereumAccountId() throws -> AccountId {
        try extractEthereumAccountId()
    }

    func normalize(for chainFormat: ChainFormat) -> AccountAddress? {
        try? toAccountId(using: chainFormat).toAddress(using: chainFormat)
    }

    func toLegacySubstrateAddress(for chainFormat: ChainFormat) throws -> AccountAddress? {
        guard
            case let .substrate(_, legacyPrefix) = chainFormat,
            let legacyPrefix
        else { return nil }

        let factory = SS58AddressFactory()
        let accountId = try toAccountId(using: chainFormat)
        let legacyAddress = try factory.address(fromAccountId: accountId, type: legacyPrefix)

        return legacyAddress
    }
}

extension ChainModel {
    var chainFormat: ChainFormat {
        if isEthereumBased {
            .ethereum
        } else if isTronBased {
            .tron
        } else {
            .substrate(
                addressPrefix.toSubstrateFormat(),
                legacyPrefix: legacyAddressPrefix?.toSubstrateFormat()
            )
        }
    }
}
