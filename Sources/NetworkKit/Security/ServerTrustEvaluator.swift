import Foundation
import Security
import CryptoKit

/// Evaluates server trust during the TLS handshake to support certificate and
/// public-key pinning.
public protocol ServerTrustEvaluator: Sendable {
    /// Returns `true` if the trust object is acceptable for the given host.
    func evaluate(_ trust: SecTrust, forHost host: String) -> Bool
}

/// Pins against a set of SHA-256 hashes of the server's certificate
/// public keys (SPKI). This is the recommended pinning strategy.
public struct PublicKeyPinningEvaluator: ServerTrustEvaluator {
    /// Base64-encoded SHA-256 hashes of the pinned public keys, per host.
    private let pinnedKeyHashes: [String: Set<String>]

    public init(pinnedKeyHashes: [String: Set<String>]) {
        self.pinnedKeyHashes = pinnedKeyHashes
    }

    public func evaluate(_ trust: SecTrust, forHost host: String) -> Bool {
        guard let pinned = pinnedKeyHashes[host], !pinned.isEmpty else {
            // No pins configured for this host: defer to system evaluation.
            return Self.systemTrust(trust)
        }
        guard Self.systemTrust(trust) else { return false }

        let chain = (SecTrustCopyCertificateChain(trust) as? [SecCertificate]) ?? []
        for certificate in chain {
            if let hash = Self.publicKeyHash(for: certificate), pinned.contains(hash) {
                return true
            }
        }
        return false
    }

    static func systemTrust(_ trust: SecTrust) -> Bool {
        var error: CFError?
        return SecTrustEvaluateWithError(trust, &error)
    }

    static func publicKeyHash(for certificate: SecCertificate) -> String? {
        guard let publicKey = SecCertificateCopyKey(certificate),
              let data = SecKeyCopyExternalRepresentation(publicKey, nil) as Data? else {
            return nil
        }
        let digest = SHA256.hash(data: data)
        return Data(digest).base64EncodedString()
    }
}

/// `URLSession` delegate that enforces a `ServerTrustEvaluator` and HTTPS.
public final class SecuritySessionDelegate: NSObject, URLSessionDelegate, Sendable {
    private let evaluator: ServerTrustEvaluator?

    public init(evaluator: ServerTrustEvaluator?) {
        self.evaluator = evaluator
    }

    public func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        guard let evaluator else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        if evaluator.evaluate(trust, forHost: challenge.protectionSpace.host) {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}
