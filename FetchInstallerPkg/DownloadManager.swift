//
//  DownloadManager.swift
//  FetchInstallerPkg
//
//  Created by Armin Briegel on 2021-06-14.
//

import Foundation
import AppKit

@objc class DownloadManager: NSObject, ObservableObject {
    @Published var downloadURL: URL?
    @Published var localURL: URL?
    @Published var isDownloading = false
    @Published var progress: Double = 0.0
    @Published var progressString: String = ""
    @Published var isComplete = false
    
    lazy var urlSession = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: nil)
    var downloadTask : URLSessionDownloadTask?
    var byteFormatter = ByteCountFormatter()
    
    static let shared = DownloadManager()
    
    func download(url: URL?) {
        // reset the variables
        progress = 0.0
        isDownloading = true
        localURL = nil
        downloadURL = url
        isComplete = false
        
        byteFormatter.countStyle = .file
        
        if url != nil {
            downloadTask = urlSession.downloadTask(with: url!)
            downloadTask!.resume()
        }
    }
    
    func cancel() {
        if isDownloading && downloadTask != nil {
            downloadTask?.cancel()
            isDownloading = false
            localURL = nil
            downloadURL = nil
            progress = 0.0
        }
    }
    
    func revealInFinder() {
        if isComplete {
            guard let destination = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first else { return }
            NSWorkspace.shared.selectFile(localURL?.path, inFileViewerRootedAtPath: destination.path)
        }
    }
}

extension DownloadManager : URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        NSLog("urlSession, didFinishDownloading")
        guard
            let cache = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        else {
            return
        }
        
        // get the suggest file name or create a uuid string
        let suggestedFilename = downloadTask.response?.suggestedFilename ?? UUID().uuidString
        
        do {
            let file = cache.appendingPathComponent(suggestedFilename)
            let newURL = try FileManager.default.replaceItemAt(file, withItemAt: location)
            NSLog("downloaded to \(newURL?.path ?? "something went wrong")")
            DispatchQueue.main.async {
                self.isDownloading = false
                self.localURL = newURL
                self.isComplete = true
            }
        }
        catch {
            NSLog(error.localizedDescription)
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        NSLog("urlSession, didWriteData: \(totalBytesWritten)/\(totalBytesExpectedToWrite)")
        DispatchQueue.main.async {
            self.progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            self.progressString = "\(self.byteFormatter.string(fromByteCount: totalBytesWritten))/\(self.byteFormatter.string(fromByteCount: totalBytesExpectedToWrite))"
        }
    }
}
