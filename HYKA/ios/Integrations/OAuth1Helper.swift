import Foundation
import CryptoKit
import Security

/// Helper class for OAuth 1.0a signature generation
final class OAuth1Helper {
    
    /// Generate OAuth 1.0a signature for a request
    static func generateSignature(
        method: String,
        url: URL,
        parameters: [String: String],
        consumerKey: String,
        consumerSecret: String,
        token: String? = nil,
        tokenSecret: String? = nil
    ) -> String {
        // Normalize parameters
        var allParams = parameters
        allParams["oauth_consumer_key"] = consumerKey
        allParams["oauth_nonce"] = generateNonce()
        allParams["oauth_signature_method"] = "HMAC-SHA1"
        allParams["oauth_timestamp"] = String(Int(Date().timeIntervalSince1970))
        allParams["oauth_version"] = "1.0"
        
        if let token = token {
            allParams["oauth_token"] = token
        }
        
        // Sort parameters and create signature base string
        let sortedParams = allParams.sorted { $0.key < $1.key }
        let paramString = sortedParams.map { "\(percentEncode($0.key))=\(percentEncode($0.value))" }.joined(separator: "&")
        
        // Create signature base string
        // Use normalized URL (scheme + host + port + path, no query parameters)
        var normalizedURL = "\(url.scheme ?? "https")://\(url.host ?? "")"
        if let port = url.port, (url.scheme == "http" && port != 80) || (url.scheme == "https" && port != 443) {
            normalizedURL += ":\(port)"
        }
        normalizedURL += url.path.isEmpty ? "/" : url.path
        
        let signatureBaseString = "\(method)&\(percentEncode(normalizedURL))&\(percentEncode(paramString))"
        
        // Create signing key
        let signingKey = "\(percentEncode(consumerSecret))&\(percentEncode(tokenSecret ?? ""))"
        
        // Generate HMAC-SHA1 signature
        let keyData = Data(signingKey.utf8)
        let messageData = Data(signatureBaseString.utf8)
        let hmac = HMAC<Insecure.SHA1>.authenticationCode(for: messageData, using: SymmetricKey(data: keyData))
        let signature = Data(hmac).base64EncodedString()
        
        return signature
    }
    
    /// Generate OAuth 1.0a authorization header
    /// Follows Garmin API specification exactly
    static func generateAuthorizationHeader(
        consumerKey: String,
        consumerSecret: String,
        token: String? = nil,
        tokenSecret: String? = nil,
        method: String,
        url: URL,
        parameters: [String: String] = [:]
    ) -> String {
        // Use consistent nonce and timestamp for signature and header
        // Generate timestamp immediately to minimize clock skew with Garmin's servers
        let nonce = generateNonce()
        let timestamp = Int(Date().timeIntervalSince1970)
        let timestampString = String(timestamp)
        
        // Print timestamp for debugging
        print("🕐 Timestamp: \(timestamp) (Unix epoch seconds)")
        print("   Timestamp value: \(Int(Date().timeIntervalSince1970))")
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        print("   Current date: \(formatter.string(from: Date()))")
        
        // Validate timestamp is reasonable (not in the past, not too far in future)
        let now = Int(Date().timeIntervalSince1970)
        let timeDiff = abs(timestamp - now)
        if timeDiff > 300 { // More than 5 minutes difference
            print("⚠️ Warning: Timestamp differs from current time by \(timeDiff) seconds")
        }
        
        // Build base URL (normalized - scheme + host + path, no query params)
        var baseURL = "\(url.scheme ?? "https")://\(url.host ?? "")"
        if let port = url.port, (url.scheme == "http" && port != 80) || (url.scheme == "https" && port != 443) {
            baseURL += ":\(port)"
        }
        baseURL += url.path.isEmpty ? "/" : url.path
        
        // Collect and percent-encode all parameters
        var params: [String: String] = parameters
        params["oauth_consumer_key"] = consumerKey
        params["oauth_nonce"] = nonce
        params["oauth_signature_method"] = "HMAC-SHA1"
        params["oauth_timestamp"] = timestampString
        params["oauth_version"] = "1.0"
        
        if let token = token {
            params["oauth_token"] = token
        }
        
        // Alphabetically sort and join parameters
        // Encode both keys and values per OAuth 1.0a specification
        // Use strict RFC 3986 encoding via percentEncode function
        let encodedPairs = params
            .map { (percentEncode($0.key), percentEncode($0.value)) }
            .sorted { lhs, rhs in
                if lhs.0 == rhs.0 {
                    return lhs.1 < rhs.1
                }
                return lhs.0 < rhs.0
            }
        let paramString = encodedPairs
            .map { "\($0)=\($1)" }
            .joined(separator: "&")
        
        // Build signature base string
        // Use strict RFC 3986 encoding for both URL and parameter string
        let encodedBaseURL = percentEncode(baseURL)
        let encodedParamString = percentEncode(paramString)
        let signatureBase = "\(method)&\(encodedBaseURL)&\(encodedParamString)"
        
        print("🔐 OAuth 1.0a Signature Debug:")
        print("   Method: \(method)")
        print("   Base URL: \(baseURL)")
        print("   Base URL (encoded): \(encodedBaseURL)")
        print("   Timestamp: \(timestampString)")
        print("   Nonce: \(nonce) (length: \(nonce.count))")
        print("   Parameters (raw): \(params.sorted(by: { $0.key < $1.key }).map { "\($0.key)=\($0.value)" }.joined(separator: "&"))")
        print("   Parameters (encoded): \(paramString)")
        print("   Parameters (double-encoded for base string): \(encodedParamString)")
        print("   Signature Base String: \(signatureBase)")
        
        // Sign with HMAC-SHA1
        // Signing key: percentEncode(consumerSecret) + "&" + percentEncode(tokenSecret)
        let signingKey = "\(percentEncode(consumerSecret))&\(percentEncode(tokenSecret ?? ""))"
        
        let keyData = Data(signingKey.utf8)
        let baseData = Data(signatureBase.utf8)
        let hmac = HMAC<Insecure.SHA1>.authenticationCode(for: baseData, using: SymmetricKey(data: keyData))
        let signature = Data(hmac).base64EncodedString()
        
        print("   Signing Key: \(signingKey.prefix(50))...")
        print("   Signature: \(signature)")
        
        // Build authorization header
        var headerParams: [String: String] = [
            "oauth_consumer_key": consumerKey,
            "oauth_nonce": nonce,
            "oauth_signature_method": "HMAC-SHA1",
            "oauth_timestamp": timestampString,
            "oauth_version": "1.0",
            "oauth_signature": signature
        ]
        
        if let token = token {
            headerParams["oauth_token"] = token
        }
        
        // Add oauth_callback to header if present
        if let callback = parameters["oauth_callback"] {
            headerParams["oauth_callback"] = callback
        }
        
        // Build header string - sort keys and percent-encode keys/values
        // Use strict RFC 3986 encoding for header values
        let authHeaderPairs = headerParams
            .map { (percentEncode($0.key), percentEncode($0.value)) }
            .sorted { lhs, rhs in
                lhs.0 < rhs.0
            }
        let authHeader = "OAuth " + authHeaderPairs
            .map { "\($0)=\"\($1)\"" }
            .joined(separator: ", ")
        
        print("   Authorization Header: \(authHeader.prefix(150))...")
        
        return authHeader
    }
    
    /// Generate random nonce for OAuth
    /// Garmin requires a unique, random nonce per request
    /// Using a combination of timestamp and random bytes for maximum uniqueness
    private static func generateNonce() -> String {
        // Generate random bytes and convert to hex string
        // This ensures true randomness and uniqueness
        var randomBytes = [UInt8](repeating: 0, count: 16)
        let status = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        
        if status == errSecSuccess {
            // Convert to hexadecimal string (32 characters)
            let hexString = randomBytes.map { String(format: "%02x", $0) }.joined()
            return hexString
        } else {
            // Fallback to UUID-based nonce if SecRandomCopyBytes fails
            let uuid = UUID().uuidString.replacingOccurrences(of: "-", with: "")
            return uuid.lowercased()
        }
    }
    
    /// Percent encode string according to RFC 3986 (OAuth 1.0a spec)
    /// Only ALPHA, DIGIT, '-', '.', '_', '~' are not encoded
    private static func percentEncode(_ string: String) -> String {
        // OAuth 1.0a requires strict percent encoding
        // Only these characters are not encoded: ALPHA, DIGIT, '-', '.', '_', '~'
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        return string.addingPercentEncoding(withAllowedCharacters: allowed) ?? string
    }
    
    /// Parse OAuth response parameters from URL or response body
    static func parseOAuthResponse(_ response: String) -> [String: String] {
        var params: [String: String] = [:]
        let components = response.components(separatedBy: "&")
        for component in components {
            let parts = component.components(separatedBy: "=")
            if parts.count == 2 {
                let key = parts[0].removingPercentEncoding ?? parts[0]
                let value = parts[1].removingPercentEncoding ?? parts[1]
                params[key] = value
            }
        }
        return params
    }
}

