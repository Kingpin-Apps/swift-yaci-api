import Foundation

public enum YaciAPIError: Error, CustomStringConvertible, Equatable, Sendable {
    case invalidBasePath(String?)
    case missingAPIKey(String?)
    case valueError(String?)
    
    public var description: String {
        switch self {
            case .invalidBasePath(let message):
                return message ?? "Invalid base path."
            case .missingAPIKey(let message):
                return message ?? "The API Key is missing."
            case .valueError(let message):
                return message ?? "The value is invalid."
        }
    }
}
