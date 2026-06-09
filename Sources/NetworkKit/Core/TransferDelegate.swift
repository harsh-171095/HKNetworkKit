import Foundation

/// A per-task `URLSession` delegate that reports upload/download progress and
/// forwards TLS challenges to a `ServerTrustEvaluator`.
final class TransferDelegate: NSObject, URLSessionTaskDelegate, URLSessionDownloadDelegate, @unchecked Sendable {
    private let evaluator: ServerTrustEvaluator?
    private let onProgress: ProgressHandler?

    init(evaluator: ServerTrustEvaluator?, onProgress: ProgressHandler?) {
        self.evaluator = evaluator
        self.onProgress = onProgress
    }

    // MARK: Upload progress

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        onProgress?(TransferProgress(completedBytes: totalBytesSent, totalBytes: totalBytesExpectedToSend))
    }

    // MARK: Download progress

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        onProgress?(TransferProgress(completedBytes: totalBytesWritten, totalBytes: totalBytesExpectedToWrite))
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // The async `download(for:delegate:)` API surfaces the location directly;
        // this method is required by the protocol but needs no extra handling.
    }

    // MARK: TLS challenge

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust,
              let evaluator else {
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
