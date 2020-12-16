//
//  GnosisError.swift
//  Multisig
//
//  Created by Andrey Scherbovich on 14.12.20.
//  Copyright © 2020 Gnosis Ltd. All rights reserved.
//

import Foundation

protocol DetailedLocalizedError: LocalizedError, LoggableError {
    var description: String { get }
    var reason: String { get }
    var howToFix: String { get }
    var loggable: Bool { get }
}

extension DetailedLocalizedError {
    var errorDescription: String? {
        return "\(description): \(reason) \(howToFix) (Error \(code))"
    }
}

/// Gnosis Safe errors as specified here in the requirements
enum GSError {
    private static let networkErrorDomain = "NetworkError"
    private static let clientErrorDomain = "CommonClientError"
    private static let iOSErrorDomain = "iOSError"

    private static let unexpectedError = UnprocessableEntity(
        reason: "Network request failed with an unexpected error.", code: 42200)

    /// User facing error from underlying error
    /// - Parameters:
    ///   - description: User facing description
    ///   - error: undrelying error
    /// - Returns: Detailed localized error
    static func error(description: String, error: Error) -> DetailedLocalizedError {
        struct AppError: DetailedLocalizedError {
            let description: String
            let reason: String
            let howToFix: String
            let domain: String
            let code: Int
            let loggable: Bool
        }

        if let error = error as? DetailedLocalizedError {
            return AppError(description: description,
                            reason: error.reason,
                            howToFix: error.howToFix,
                            domain: error.domain,
                            code: error.code,
                            loggable: error.loggable)
        } else if let error = error as? LocalizedError {
            return UnknownAppError(description: description,
                                   reason: error.failureReason ?? error.localizedDescription,
                                   howToFix: error.recoverySuggestion ?? "")
        } else {
            let error = error as NSError
            return UnknownAppError(
                description: description,
                reason: error.localizedFailureReason ?? error.localizedDescription,
                howToFix: error.localizedRecoverySuggestion ?? "")
        }
    }

    static func detailedError(from error: Error) -> Error {
        guard let nsError = error as NSError? else { return error }

        switch URLError.Code(rawValue: nsError.code) {
        case .notConnectedToInternet:
            return NoInternet()
        case .secureConnectionFailed:
            return SecureConnectionFailed()
        case .timedOut:
            return TimeOut()
        case .cannotFindHost:
            return UnknownHost()
        default:
            return error
        }
    }

    static func detailedError(from httpResponse: HTTPURLResponse, data: Data?) -> Error {
        switch httpResponse.statusCode {
        case 200...299:
            preconditionFailure("Not an error, please check the calling code")
        case 404:
            return EntityNotFound()
        case 422:
            return unprocessableEntity(data: data)
        case 300...599:
            return ServerSideError(code: httpResponse.statusCode)
        default:
            let error = UnknownNetworkError(code: httpResponse.statusCode)
            LogService.shared.error("Unknown error with status code: \(httpResponse.statusCode)", error: error)
            return UnknownNetworkError(code: httpResponse.statusCode)
        }
    }

    private static func unprocessableEntity(data: Data?) -> Error {
        guard let data = data else {
            LogService.shared.error("Missing data in unprocessableEntity error", error: unexpectedError)
            return unexpectedError
        }

        do {
            let error = try JSONDecoder().decode(BackendError.self, from: data)
            switch error.code {
            case 1:
                return UnprocessableEntity(reason: "Address format is not valid.", code: 42201)
            case 50:
                return UnprocessableEntity(reason: "Safe info is not found.", code: 42250)
            default:
                LogService.shared.error("Unrecognised error with code: \(error.code); message: \(error.message)",
                                        error: unexpectedError)
                return unexpectedError
            }
        } catch {
            let dataString = String(data: data, encoding: .utf8) ?? data.base64EncodedString()
            LogService.shared.error("Could not decode error details from the data: \(dataString)",
                                    error: unexpectedError)
            return unexpectedError
        }
    }

    fileprivate struct BackendError: Decodable {
        let code: Int
        let message: String
    }

    // MARK: - Network errors

    struct NoInternet: DetailedLocalizedError {
        let description = "No Internet"
        let reason = "Device is not connected to the Internet."
        let howToFix = "Please try again when Internet is available"

        let domain = networkErrorDomain
        let code = 101
        let loggable = false
    }

    struct SecureConnectionFailed: DetailedLocalizedError {
        let description = "SSL connection failed"
        let reason = "SSL connection failed."
        let howToFix = "Please try again later"

        let domain = networkErrorDomain
        let code = 102
        let loggable = false
    }

    struct TimeOut: DetailedLocalizedError {
        let description = "Request timed out"
        var reason: String { "Request timed out after \(String(format: "%.0f", timeOut))s." }
        let howToFix = "Please refresh the screen"

        let domain = networkErrorDomain
        let code = 103
        let loggable = false

        let timeOut = HTTPClient.timeOutIntervalForRequest
    }

    struct UnknownHost: DetailedLocalizedError {
        let description = "Unknown host, connection error"
        let reason = "Server not reachable."
        let howToFix = "Please try again when Internet is available"

        let domain = networkErrorDomain
        let code = 104
        let loggable = false
    }

    struct EntityNotFound: DetailedLocalizedError {
        let description = "HTTP 404 Not Found"
        let reason = "Safe not found."
        let howToFix = "Please check that the Safe exists on the blockchain"
        let domain = networkErrorDomain
        let code = 404
        let loggable = false
    }

    struct UnprocessableEntity: DetailedLocalizedError {
        let description = "HTTP 422 Unprocessable Entity"
        let reason: String
        let howToFix = "Please reach out to the Safe support"
        let domain = networkErrorDomain
        let code: Int
        let loggable = true
    }

    struct ServerSideError: DetailedLocalizedError {
        let description = "HTTP 3xx, 4xx, 5xx"
        let reason = "Server-side error."
        let howToFix = "Please try again later or contact Safe support if the issue persists"
        let domain = networkErrorDomain
        let code: Int
        let loggable = false
    }

    struct UnknownNetworkError: DetailedLocalizedError {
        let description = "Unknown error"
        let reason = "Unexpected network error."
        let howToFix = "Please reach out to the Safe support"
        let domain = networkErrorDomain
        let code: Int
        let loggable = true
    }

    // MARK: - Common client errors

    struct WrongSeedPhrase: DetailedLocalizedError {
        let description = "Can’t use this seed phrase"
        let reason = "This is not a valid seed phrase for an Ethereum account."
        let howToFix = "Please correct the error or use another seed phrase"
        let domain = clientErrorDomain
        let code = 1103
        let loggable = false
    }

    struct TransactionSigningError: DetailedLocalizedError {
        let description = "Failed to confirm transaction"
        let reason = "Computed safeTxHash of a transaction to confirm does not match server-returned value."
        let howToFix = "Please reload the data or check that your network is secure."
        let domain = clientErrorDomain
        let code = 1104
        let loggable = false
    }

    struct InvalidSafeName: DetailedLocalizedError {
        let description = "Can’t use this name"
        let reason = "This value is not a valid name."
        let howToFix = "Name should not be empty"
        let domain = clientErrorDomain
        let code = 1110
        let loggable = false
    }

    // MARK: - iOS errors

    struct UnknownAppError: DetailedLocalizedError {
        let description: String
        let reason: String
        let howToFix: String
        let domain = iOSErrorDomain
        let code = 1300
        let loggable = true
    }

    struct PreconditionsForSigningNotSatisfied: DetailedLocalizedError {
        let description: String
        let reason = "Something is wrong either with the transaction data or with the application state (database, selected Safe, etc.)"
        let howToFix = "Please reinstall the Gnosis Safe app"
        let domain = iOSErrorDomain
        let code = 1304
        let loggable = true
    }

    struct KeychainError: DetailedLocalizedError {
        let description = "Keychain error"
        let reason: String
        let howToFix = "Please reinstall the Gnosis Safe app"
        let domain = iOSErrorDomain
        let code = 1305
        let loggable = true
    }

    struct DatabaseError: DetailedLocalizedError {
        let description = "Database error"
        let reason: String
        let howToFix = "Please reinstall the Gnosis Safe app"
        let domain = iOSErrorDomain
        let code = 1306
        let loggable = true
    }

}