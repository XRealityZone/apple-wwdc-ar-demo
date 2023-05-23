/*
See LICENSE folder for this sample’s licensing information.

Abstract:
RealityKit Object Creation command line tools.
*/

import ArgumentParser  // Available from Apple: https://github.com/apple/swift-argument-parser
import Foundation
import os
import RealityKit
import Metal

private let logger = Logger(subsystem: "com.apple.sample.photogrammetry",
                            category: "HelloPhotogrammetry")

/// Implements the main command structure, defines the command-line arguments,
/// and specifies the main run loop.
struct HelloPhotogrammetry: ParsableCommand {
    
    private typealias Configuration = PhotogrammetrySession.Configuration
    private typealias Request = PhotogrammetrySession.Request
    
    public static let configuration = CommandConfiguration(
        abstract: "Reconstructs 3D USDZ model from a folder of images.")
    
    @Argument(help: "The local input file folder of images.")
    private var inputFolder: String
    
    @Argument(help: "Full path to the USDZ output file.")
    private var outputFilename: String
    
    @Option(name: .shortAndLong,
            parsing: .next,
            help: "detail {preview, reduced, medium, full, raw}  Detail of output model in terms of mesh size and texture size.",
            transform: Request.Detail.init)
    private var detail: Request.Detail? = nil
    
    @Option(name: [.customShort("o"), .long],
            parsing: .next,
            help: "sampleOrdering {unordered, sequential}  Setting to sequential may speed up computation if images are captured in a spatially sequential pattern.",
            transform: Configuration.SampleOrdering.init)
    private var sampleOrdering: Configuration.SampleOrdering?
    
    @Option(name: .shortAndLong,
            parsing: .next,
            help: "featureSensitivity {normal, high}  Set to high if the scanned object does not contain a lot of discernible structures, edges or textures.",
            transform: Configuration.FeatureSensitivity.init)
    private var featureSensitivity: Configuration.FeatureSensitivity?
    
    /// The main run loop entered at the end of the file.
    func run() {
        guard PhotogrammetrySession.isSupported else {
            logger.error("Program terminated early because the hardware doesn't support Object Capture.")
            print("Object Capture is not available on this computer.")
            Foundation.exit(1)
        }
        
        let inputFolderUrl = URL(fileURLWithPath: inputFolder, isDirectory: true)
        let configuration = makeConfigurationFromArguments()
        logger.log("Using configuration: \(String(describing: configuration))")
        
        // Try to create the session, or else exit.
        var maybeSession: PhotogrammetrySession? = nil
        do {
            maybeSession = try PhotogrammetrySession(input: inputFolderUrl,
                                                     configuration: configuration)
            logger.log("Successfully created session.")
        } catch {
            logger.error("Error creating session: \(String(describing: error))")
            Foundation.exit(1)
        }
        guard let session = maybeSession else {
            Foundation.exit(1)
        }
        
        let waiter = Task {
            do {
                for try await output in session.outputs {
                    switch output {
                        case .processingComplete:
                            logger.log("Processing is complete!")
                            Foundation.exit(0)
                        case .requestError(let request, let error):
                            logger.error("Request \(String(describing: request)) had an error: \(String(describing: error))")
                        case .requestComplete(let request, let result):
                            HelloPhotogrammetry.handleRequestComplete(request: request, result: result)
                        case .requestProgress(let request, let fractionComplete):
                            HelloPhotogrammetry.handleRequestProgress(request: request,
                                                                      fractionComplete: fractionComplete)
                        case .inputComplete:  // data ingestion only!
                            logger.log("Data ingestion is complete.  Beginning processing...")
                        case .invalidSample(let id, let reason):
                            logger.warning("Invalid Sample! id=\(id)  reason=\"\(reason)\"")
                        case .skippedSample(let id):
                            logger.warning("Sample id=\(id) was skipped by processing.")
                        case .automaticDownsampling:
                            logger.warning("Automatic downsampling was applied!")
                        case .processingCancelled:
                            logger.warning("Processing was cancelled.")
                        @unknown default:
                            logger.error("Output: unhandled message: \(output.localizedDescription)")

                    }
                }
            } catch {
                logger.error("Output: ERROR = \(String(describing: error))")
                Foundation.exit(0)
            }
        }
        
        // The compiler may deinitialize these objects since they may appear to be
        // unused. This keeps them from being deallocated until they exit.
        withExtendedLifetime((session, waiter)) {
            // Run the main process call on the request, then enter the main run
            // loop until you get the published completion event or error.
            do {
                let request = makeRequestFromArguments()
                logger.log("Using request: \(String(describing: request))")
                try session.process(requests: [ request ])
                // Enter the infinite loop dispatcher used to process asynchronous
                // blocks on the main queue. You explicitly exit above to stop the loop.
                RunLoop.main.run()
            } catch {
                logger.critical("Process got error: \(String(describing: error))")
                Foundation.exit(1)
            }
        }
    }

    /// Creates the session configuration by overriding any defaults with arguments specified.
    private func makeConfigurationFromArguments() -> PhotogrammetrySession.Configuration {
        var configuration = PhotogrammetrySession.Configuration()
        sampleOrdering.map { configuration.sampleOrdering = $0 }
        featureSensitivity.map { configuration.featureSensitivity = $0 }
        return configuration
    }

    /// Creates a request to use based on the command-line arguments.
    private func makeRequestFromArguments() -> PhotogrammetrySession.Request {
        let outputUrl = URL(fileURLWithPath: outputFilename)
        if let detailSetting = detail {
            return PhotogrammetrySession.Request.modelFile(url: outputUrl, detail: detailSetting)
        } else {
            return PhotogrammetrySession.Request.modelFile(url: outputUrl)
        }
    }
    
    /// Called when the the session sends a request completed message.
    private static func handleRequestComplete(request: PhotogrammetrySession.Request,
                                              result: PhotogrammetrySession.Result) {
        logger.log("Request complete: \(String(describing: request)) with result...")
        switch result {
            case .modelFile(let url):
                logger.log("\tmodelFile available at url=\(url)")
            default:
                logger.warning("\tUnexpected result: \(String(describing: result))")
        }
    }
    
    /// Called when the sessions sends a progress update message.
    private static func handleRequestProgress(request: PhotogrammetrySession.Request,
                                              fractionComplete: Double) {
        logger.log("Progress(request = \(String(describing: request)) = \(fractionComplete)")
    }

}

// MARK: - Helper Functions / Extensions

private func handleRequestProgress(request: PhotogrammetrySession.Request,
                                   fractionComplete: Double) {
    print("Progress(request = \(String(describing: request)) = \(fractionComplete)")
}

/// Error thrown when an illegal option is specified.
private enum IllegalOption: Swift.Error {
    case invalidDetail(String)
    case invalidSampleOverlap(String)
    case invalidSampleOrdering(String)
    case invalidFeatureSensitivity(String)
}

/// Extension to add a throwing initializer used as an option transform to verify the user-supplied arguments.
@available(macOS 12.0, *)
extension PhotogrammetrySession.Request.Detail {
    init(_ detail: String) throws {
        switch detail {
            case "preview": self = .preview
            case "reduced": self = .reduced
            case "medium": self = .medium
            case "full": self = .full
            case "raw": self = .raw
            default: throw IllegalOption.invalidDetail(detail)
        }
    }
}

@available(macOS 12.0, *)
extension PhotogrammetrySession.Configuration.SampleOrdering {
    init(sampleOrdering: String) throws {
        if sampleOrdering == "unordered" {
            self = .unordered
        } else if sampleOrdering == "sequential" {
            self = .sequential
        } else {
            throw IllegalOption.invalidSampleOrdering(sampleOrdering)
        }
    }
    
}

@available(macOS 12.0, *)
extension PhotogrammetrySession.Configuration.FeatureSensitivity {
    init(featureSensitivity: String) throws {
        if featureSensitivity == "normal" {
            self = .normal
        } else if featureSensitivity == "high" {
            self = .high
        } else {
            throw IllegalOption.invalidFeatureSensitivity(featureSensitivity)
        }
    }
}

// MARK: - Main

// Run the program until completion.
if #available(macOS 12.0, *) {
    HelloPhotogrammetry.main()
} else {
    fatalError("Requires minimum macOS 12.0!")
}
