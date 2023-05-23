/*
See LICENSE folder for this sample’s licensing information.

Abstract:
An object that loads the remote file and caches it for later use.
*/

import UIKit
import RealityKit
import ARKit
import Combine

class CachingWebLoader: NSObject, URLSessionDelegate, URLSessionTaskDelegate, URLSessionDownloadDelegate {
    
    // The class' singleton instance.
    public static let shared = CachingWebLoader()
    
    fileprivate var handlersFor: [URLSessionDownloadTask: DownloadTaskHandlers] = [:]
    
    private var loaderFor: [URL: CachedWebLoad] = [:]
    private lazy var urlSession = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    
    public func cachedWebLoad(url: URL) -> CachedWebLoad {
        if let loader = loaderFor[url] {
            return loader
        } else {
            let task = urlSession.downloadTask(with: url)
            handlersFor[task] = DownloadTaskHandlers()
            loaderFor[url] = CachedWebLoad(downloadTask: task)
            return loaderFor[url]!
        }
    }
    
    public func cachedWebLoad(url: URL, successHandler: @escaping (URL) -> Void) -> CachedWebLoad {
        let loader = cachedWebLoad(url: url)
        loader.addSuccessHandler(successHandler)
        return loader
    }
    
    fileprivate func processProgressingTask(forTask task: URLSessionDownloadTask, progress: Float) {
        for progressHandler in handlersFor[task]!.downloadProgressHandlers {
            progressHandler(progress)
        }
    }
    
    fileprivate func processSuccessfulTask(forTask task: URLSessionDownloadTask, urlForSaveLocation: URL) {
        for successHandler in handlersFor[task]!.downloadSuccessHandlers {
            successHandler(urlForSaveLocation)
        }
        // Notify subscribers only once by emptying the handlers list.
        handlersFor[task]!.downloadSuccessHandlers = []
    }
    
    fileprivate func processFailedTask(forTask task: URLSessionDownloadTask, withErrorMessage errorMessage: String) {
        task.cancel()
        debugPrint(errorMessage)
        for errorHandler in handlersFor[task]!.downloadErrorHandlers {
            errorHandler(errorMessage)
        }
        loaderFor.removeValue(forKey: task.originalRequest!.url!)
    }
    
    // MARK: URLSessionDownloadDelegate callbacks
    internal func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        debugPrint("Bytes loaded: \(totalBytesWritten).")
        let fractionalProgress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
        processProgressingTask(forTask: downloadTask, progress: fractionalProgress)
    }
        
    internal func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        debugPrint("Download finished: \(location)")
        let documentDirectoryPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first! as NSString
        let destinationPath = documentDirectoryPath.appendingPathComponent(
            downloadTask.originalRequest!.url!.lastPathComponent
        )
        let localURLToSaveFile = URL(fileURLWithPath: destinationPath)
        do {
            try FileManager.default.copyItem(at: location, to: localURLToSaveFile)
        } catch {
            processFailedTask(forTask: downloadTask, withErrorMessage: error.localizedDescription)
        }
        if FileManager.default.fileExists(atPath: localURLToSaveFile.path) {
            debugPrint("File has been successfully created and saved: \(localURLToSaveFile.path)")
            processSuccessfulTask(forTask: downloadTask, urlForSaveLocation: localURLToSaveFile)
        } else {
            let errorMessage = "File creation failed: \(localURLToSaveFile.path)"
            debugPrint(errorMessage)
            processFailedTask(forTask: downloadTask, withErrorMessage: errorMessage)
        }
    }

    // MARK: // URLSessionDelegate call-back
    internal func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        // A successful download calls this delegate with the error argument set to `nil`.
        if let errorMessage = error?.localizedDescription {
            debugPrint(errorMessage)
        }
    }
    
    // MARK: // URLSessionTaskDelegate call-backs
    internal func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let errorMessage = error?.localizedDescription {
            debugPrint(errorMessage)
        }
    }
    
    internal func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        if let errorMessage = challenge.error?.localizedDescription {
            debugPrint(errorMessage)
        } else {
            // Call the completion handler to continue the load.
            completionHandler(URLSession.AuthChallengeDisposition.performDefaultHandling, nil)
        }
    }
    
    // Creates a new instance via private-only access, such as a class singleton.
    private override init() {
        super.init()
    }
    
    fileprivate struct DownloadTaskHandlers {
        var downloadProgressHandlers: [(_: Float) -> Void] = []
        var downloadSuccessHandlers: [(_: URL) -> Void] = []
        var downloadErrorHandlers: [(_: String) -> Void] = []
    }
}

class CachedWebLoad {
    private var downloadTask: URLSessionDownloadTask!
    
    init(downloadTask: URLSessionDownloadTask) {
        self.downloadTask = downloadTask
    }
    
    public func start() {
        if let documentDirectoryPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first {
            let pathToCheckForFileExistance = NSString(
                string: documentDirectoryPath).appendingPathComponent((downloadTask.originalRequest?.url?.lastPathComponent)!
            )
            debugPrint("Checking for file at" + pathToCheckForFileExistance)
            if FileManager.default.fileExists(atPath: pathToCheckForFileExistance) {
                debugPrint("File was already saved locally.")
                CachingWebLoader.shared.processSuccessfulTask(
                    forTask: downloadTask,
                    urlForSaveLocation: URL(fileURLWithPath: pathToCheckForFileExistance)
                )
            } else {
                debugPrint("File will be loaded from web.")
                if downloadTask.state == .suspended { downloadTask.resume() }
            }
        } else {
            debugPrint("The documents folder could not be accessed.")
        }
    }
    
    public func cancel() {
        downloadTask.cancel()
    }
    
    public func addSuccessHandler(_ successHandler: @escaping (_: URL) -> Void) {
        CachingWebLoader.shared.handlersFor[downloadTask]?.downloadSuccessHandlers.append(successHandler)
    }
    
    public func addErrorHandler(_ errorHandler: @escaping (_: String) -> Void) {
        CachingWebLoader.shared.handlersFor[downloadTask]?.downloadErrorHandlers.append(errorHandler)
    }
    
    public func addProgressHandler(_ progressHandler: @escaping (_: Float) -> Void) {
        CachingWebLoader.shared.handlersFor[downloadTask]?.downloadProgressHandlers.append(progressHandler)
    }
}
