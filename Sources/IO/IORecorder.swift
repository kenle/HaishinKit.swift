import AVFoundation

#if canImport(SwiftPMSupport)
    import SwiftPMSupport
#endif

/// The interface an IORecorder uses to inform its delegate.
public protocol IORecorderDelegate: AnyObject {
    /// Tells the receiver to recorder error occured.
    func recorder(_ recorder: IORecorder, errorOccured error: IORecorder.Error)
    /// Tells the receiver to finish writing.
    func recorder(_ recorder: IORecorder, finishWriting writer: AVAssetWriter)
}

// MARK: -
/// The IORecorder class represents video and audio recorder.
public final class IORecorder {
    /// The IORecorder error domain codes.
    public enum Error: Swift.Error {
        /// Failed to create the AVAssetWriter.
        case failedToCreateAssetWriter(error: any Swift.Error)
        /// Failed to create the AVAssetWriterInput.
        case failedToCreateAssetWriterInput(error: NSException)
        /// Failed to append the PixelBuffer or SampleBuffer.
        case failedToAppend(error: (any Swift.Error)?)
        /// Failed to finish writing the AVAssetWriter.
        case failedToFinishWriting(error: (any Swift.Error)?)
    }

    /// The default output settings for an IORecorder.
    public static let defaultOutputSettings: [AVMediaType: [String: Any]] = [
        .audio: [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 0,
            AVNumberOfChannelsKey: 0,
        ],
        .video: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoHeightKey: 0,
            AVVideoWidthKey: 0,
        ],
    ]

    /// Specifies the delegate.
    public weak var delegate: (any IORecorderDelegate)?
    /// Specifies the recorder settings.
    public var outputSettings: [AVMediaType: [String: Any]] = IORecorder
        .defaultOutputSettings
    /// The running indicies whether recording or not.
    public private(set) var isRunning: Atomic<Bool> = .init(false)

    private let lockQueue = DispatchQueue(
        label: "com.haishinkit.HaishinKit.IORecorder.lock"
    )
    private var isReadyForStartWriting: Bool {
        guard let writer = writer else {
            return false
        }
        return outputSettings.count == writer.inputs.count
    }
    private var writer: AVAssetWriter?
    private var writerInputs: [AVMediaType: AVAssetWriterInput] = [:]
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var audioPresentationTime: CMTime = .zero
    private var videoPresentationTime: CMTime = .zero
    private var dimensions: CMVideoDimensions = .init(width: 0, height: 0)

    // kenle added
    public var fileName: String?
    private var isPaused: Bool = false
    private var discontAudio: Bool = false
    private var discontVideo: Bool = false

    static private var enableExperimentalPause = false

    private var timeOffsetAudio = CMTime.zero
    private var timeOffsetVideo = CMTime.zero

    private var lastVideo = CMTime.zero
    private var lastAudio = CMTime.zero

    public var movieFragmentInterval: Double? {
        didSet {
            if let movieFragmentInterval {
                self.movieFragmentInterval = max(10.0, movieFragmentInterval)
            }
        }
    }

    #if os(iOS)
        private lazy var moviesDirectory: URL = {
            URL(
                fileURLWithPath: NSSearchPathForDirectoriesInDomains(
                    .documentDirectory,
                    .userDomainMask,
                    true
                )[0]
            )
        }()
    #else
        private lazy var moviesDirectory: URL = {
            URL(
                fileURLWithPath: NSSearchPathForDirectoriesInDomains(
                    .moviesDirectory,
                    .userDomainMask,
                    true
                )[0]
            )
        }()
    #endif

    /// Append a sample buffer for recording.
    public func append(_ sampleBuffer: CMSampleBuffer) {
        guard isRunning.value else {
            return
        }
        let mediaType: AVMediaType =
            (sampleBuffer.formatDescription?._mediaType == kCMMediaType_Video)
            ? .video : .audio
        lockQueue.async {
            if IORecorder.enableExperimentalPause {
                guard
                    let writer = self.writer,
                    let input = self.makeWriterInput(
                        mediaType,
                        sourceFormatHint: sampleBuffer.formatDescription
                    ),
                    self.isReadyForStartWriting
                else {
                    return
                }
                

                if self.isPaused {
                    //print("paused returning, appendSampleBuffer \(mediaType)");
                    return
                }

                //print("***experimental appendSampleBuffer \(mediaType)");

                if self.discontAudio {
                    self.discontAudio = false
                    self.timeOffsetAudio = CMTimeSubtract(
                        CMSampleBufferGetPresentationTimeStamp(sampleBuffer),
                        self.lastAudio
                    )
                }

                let adjustedBuffer =
                    self.timeOffsetAudio.value > 0
                    ? self.adjustTime(
                        of: sampleBuffer,
                        by: self.timeOffsetAudio
                    ) ?? sampleBuffer : sampleBuffer
                let pts = CMSampleBufferGetPresentationTimeStamp(adjustedBuffer)

                switch writer.status {
                case .unknown:
                    writer.startWriting()
                    writer.startSession(
                        atSourceTime: adjustedBuffer.presentationTimeStamp
                    )
                default:
                    break
                }

                if input.isReadyForMoreMediaData {
                    switch mediaType {
                    case .audio:
                        self.lastAudio = pts
                        if input.append(adjustedBuffer) {
                            self.audioPresentationTime =
                                adjustedBuffer.presentationTimeStamp
                        } else {
                            self.delegate?.recorder(
                                self,
                                errorOccured: .failedToAppend(
                                    error: writer.error
                                )
                            )

                        }
                    case .video:
                        self.lastVideo = pts
                        if input.append(adjustedBuffer) {
                            self.videoPresentationTime =
                                adjustedBuffer.presentationTimeStamp
                        } else {
                            //print("  wtf video error");
                            self.delegate?.recorder(
                                self,
                                errorOccured: .failedToAppend(
                                    error: writer.error
                                )
                            )
                        }
                    default:
                        break
                    }
                }
            } else {
                guard
                    let writer = self.writer,
                    let input = self.makeWriterInput(
                        mediaType,
                        sourceFormatHint: sampleBuffer.formatDescription
                    ),
                    self.isReadyForStartWriting
                else {
                    return
                }

                switch writer.status {
                case .unknown:
                    writer.startWriting()
                    writer.startSession(
                        atSourceTime: sampleBuffer.presentationTimeStamp
                    )
                default:
                    break
                }

                if input.isReadyForMoreMediaData {
                    switch mediaType {
                    case .audio:
                        if input.append(sampleBuffer) {
                            self.audioPresentationTime =
                                sampleBuffer.presentationTimeStamp
                        } else {
                            self.delegate?.recorder(
                                self,
                                errorOccured: .failedToAppend(
                                    error: writer.error
                                )
                            )
                        }
                    case .video:
                        if input.append(sampleBuffer) {
                            self.videoPresentationTime =
                                sampleBuffer.presentationTimeStamp
                        } else {
                            self.delegate?.recorder(
                                self,
                                errorOccured: .failedToAppend(
                                    error: writer.error
                                )
                            )
                        }
                    default:
                        break
                    }
                }
            }
        }
    }

    /// Append a pixel buffer for recording.
    public func append(
        _ pixelBuffer: CVPixelBuffer,
        withPresentationTime: CMTime
    ) {
        guard isRunning.value else {
            return
        }
        lockQueue.async {
            if IORecorder.enableExperimentalPause {
                if self.dimensions.width != pixelBuffer.width
                    || self.dimensions.height != pixelBuffer.height
                {
                    self.dimensions = .init(
                        width: Int32(pixelBuffer.width),
                        height: Int32(pixelBuffer.height)
                    )
                }
                guard
                    let writer = self.writer,
                    let input = self.makeWriterInput(
                        .video,
                        sourceFormatHint: nil
                    ),
                    let adaptor = self.makePixelBufferAdaptor(input),
                    self.isReadyForStartWriting
                        && self.videoPresentationTime.seconds
                            < withPresentationTime.seconds
                else {
                    return
                }

                if self.isPaused {
                    //print("paused returning, appendPixelBuffer");
                    return
                }

                //print("*** experimental appendPixelBuffer");

                // based on adjusted audio sample buffer time, the withPresentationTime into this function should
                // already be ajusted
                if self.discontVideo {
                    self.discontVideo = false
                    self.timeOffsetVideo = CMTimeSubtract(
                        withPresentationTime,
                        self.lastVideo
                    )
                }

                let adjustedPresentationTime =
                    self.timeOffsetVideo.value > 0
                    ? CMTimeSubtract(withPresentationTime, self.timeOffsetVideo)
                    : withPresentationTime

                guard
                    self.videoPresentationTime.seconds
                        < adjustedPresentationTime.seconds
                else {
                    return
                }

                switch writer.status {
                case .unknown:
                    writer.startWriting()
                    writer.startSession(atSourceTime: adjustedPresentationTime)
                default:
                    break
                }

                if input.isReadyForMoreMediaData {
                    //if(adjustedPresentationTime > self.lastVideo) {
                    if adaptor.append(
                        pixelBuffer,
                        withPresentationTime: adjustedPresentationTime
                    ) {
                        self.videoPresentationTime = adjustedPresentationTime
                        self.lastVideo = adjustedPresentationTime
                    } else {
                        //print("video append error");
                        self.delegate?.recorder(
                            self,
                            errorOccured: .failedToAppend(error: writer.error)
                        )
                    }
                    /*
                    } else {
                        self.videoPresentationTime = withPresentationTime
                        self.lastVideo = withPresentationTime
                        print("adjustedPresentationTime is less than last video time for some reason");
                    }
                     */
                }
            } else {
                if self.dimensions.width != pixelBuffer.width
                    || self.dimensions.height != pixelBuffer.height
                {
                    self.dimensions = .init(
                        width: Int32(pixelBuffer.width),
                        height: Int32(pixelBuffer.height)
                    )
                }
                guard
                    let writer = self.writer,
                    let input = self.makeWriterInput(
                        .video,
                        sourceFormatHint: nil
                    ),
                    let adaptor = self.makePixelBufferAdaptor(input),
                    self.isReadyForStartWriting
                        && self.videoPresentationTime.seconds
                            < withPresentationTime.seconds
                else {
                    return
                }

                switch writer.status {
                case .unknown:
                    writer.startWriting()
                    writer.startSession(atSourceTime: withPresentationTime)
                default:
                    break
                }

                if input.isReadyForMoreMediaData {
                    if adaptor.append(
                        pixelBuffer,
                        withPresentationTime: withPresentationTime
                    ) {
                        self.videoPresentationTime = withPresentationTime
                    } else {
                        self.delegate?.recorder(
                            self,
                            errorOccured: .failedToAppend(error: writer.error)
                        )
                    }
                }
            }
        }
    }

    func append(_ audioPCMBuffer: AVAudioPCMBuffer, when: AVAudioTime) {
        guard isRunning.value else {
            return
        }
        if let sampleBuffer = audioPCMBuffer.makeSampleBuffer(when) {
            append(sampleBuffer)
        }
    }

    func finishWriting() {
        guard let writer = writer else {
            delegate?.recorder(
                self,
                errorOccured: .failedToFinishWriting(error: nil)
            )
            return
        }

        print(
            "Finishing writing original, writer status: \(writer.status.rawValue)"
        )

        guard writer.status == .writing else {
            delegate?.recorder(
                self,
                errorOccured: .failedToFinishWriting(error: writer.error)
            )
            return
        }

        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()
        for (_, input) in writerInputs {
            input.markAsFinished()
        }
        writer.finishWriting {
            self.delegate?.recorder(self, finishWriting: writer)
            self.writer = nil
            self.writerInputs.removeAll()
            self.pixelBufferAdaptor = nil
            dispatchGroup.leave()
        }
        dispatchGroup.wait()
    }

    private func makeWriterInput(
        _ mediaType: AVMediaType,
        sourceFormatHint: CMFormatDescription?
    ) -> AVAssetWriterInput? {
        guard writerInputs[mediaType] == nil else {
            return writerInputs[mediaType]
        }

        var outputSettings: [String: Any] = [:]
        if let defaultOutputSettings: [String: Any] = self.outputSettings[
            mediaType
        ] {
            switch mediaType {
            case .audio:
                guard
                    let format = sourceFormatHint,
                    let inSourceFormat = format.streamBasicDescription?.pointee
                else {
                    break
                }
                for (key, value) in defaultOutputSettings {
                    switch key {
                    case AVSampleRateKey:
                        outputSettings[key] =
                            AnyUtil.isZero(value)
                            ? inSourceFormat.mSampleRate : value
                    case AVNumberOfChannelsKey:
                        outputSettings[key] =
                            AnyUtil.isZero(value)
                            ? Int(inSourceFormat.mChannelsPerFrame) : value
                    default:
                        outputSettings[key] = value
                    }
                }
            case .video:
                for (key, value) in defaultOutputSettings {
                    switch key {
                    case AVVideoHeightKey:
                        outputSettings[key] =
                            AnyUtil.isZero(value)
                            ? Int(dimensions.height) : value
                    case AVVideoWidthKey:
                        outputSettings[key] =
                            AnyUtil.isZero(value)
                            ? Int(dimensions.width) : value
                    default:
                        outputSettings[key] = value
                    }
                }
            default:
                break
            }
        }
        var input: AVAssetWriterInput?
        nstry {
            input = AVAssetWriterInput(
                mediaType: mediaType,
                outputSettings: outputSettings,
                sourceFormatHint: sourceFormatHint
            )
            input?.expectsMediaDataInRealTime = true
            self.writerInputs[mediaType] = input
            if let input {
                self.writer?.add(input)
            }
        } _: { exception in
            self.delegate?.recorder(
                self,
                errorOccured: .failedToCreateAssetWriterInput(error: exception)
            )
        }
        return input
    }

    private func makePixelBufferAdaptor(_ writerInput: AVAssetWriterInput?)
        -> AVAssetWriterInputPixelBufferAdaptor?
    {
        guard pixelBufferAdaptor == nil else {
            return pixelBufferAdaptor
        }
        guard let writerInput = writerInput else {
            return nil
        }
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: writerInput,
            sourcePixelBufferAttributes: [:]
        )
        pixelBufferAdaptor = adaptor
        return adaptor
    }
    
    private func adjustTime(of sampleBuffer: CMSampleBuffer, by offset: CMTime) -> CMSampleBuffer? {
        var count: CMItemCount = 0
        CMSampleBufferGetSampleTimingInfoArray(sampleBuffer, entryCount: 0, arrayToFill: nil, entriesNeededOut: &count)
        var timingInfo = [CMSampleTimingInfo](repeating: CMSampleTimingInfo(), count: count)
        CMSampleBufferGetSampleTimingInfoArray(sampleBuffer, entryCount: count, arrayToFill: &timingInfo, entriesNeededOut: &count)
        
        for i in 0..<count {
            timingInfo[i].decodeTimeStamp = timingInfo[i].decodeTimeStamp - offset
            timingInfo[i].presentationTimeStamp = timingInfo[i].presentationTimeStamp - offset
        }
        
        var sout: CMSampleBuffer?
        CMSampleBufferCreateCopyWithNewTiming(allocator: kCFAllocatorDefault, sampleBuffer: sampleBuffer, sampleTimingEntryCount: count, sampleTimingArray: &timingInfo, sampleBufferOut: &sout)
        return sout
    }
}

extension IORecorder: Running {
    // MARK: Running
    public func startRunning() {
        lockQueue.async {
            guard !self.isRunning.value else {
                return
            }

            do {
                self.videoPresentationTime = .zero
                self.audioPresentationTime = .zero
                let fileName = self.fileName ?? UUID().uuidString
                let url = self.moviesDirectory.appendingPathComponent(fileName)
                    .appendingPathExtension("mp4")
                self.writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
                if let movieFragmentInterval = self.movieFragmentInterval {
                    self.writer?.movieFragmentInterval = CMTime(
                        seconds: movieFragmentInterval,
                        preferredTimescale: 1
                    )
                }

                self.timeOffsetVideo = CMTime.zero
                self.timeOffsetAudio = CMTime.zero
                self.lastVideo = CMTime.zero
                self.lastAudio = CMTime.zero
                self.isPaused = false
                self.discontVideo = false
                self.discontAudio = false

                self.isRunning.mutate { $0 = true }
            } catch {
                self.delegate?.recorder(
                    self,
                    errorOccured: .failedToCreateAssetWriter(error: error)
                )
            }
        }
    }

    public func pauseRunning() {
        lockQueue.async {
            //print("Pausing capture")
            self.isPaused = true
            self.discontVideo = true
            self.discontAudio = true
            //print("isPaused = \(self.isPaused)");
        }
    }

    public func enablePause() {
        IORecorder.enableExperimentalPause = true
        print(
            "enablePause enableExperimentalPause = \(IORecorder.enableExperimentalPause)"
        )

    }

    public func disablePause() {
        IORecorder.enableExperimentalPause = false
        print(
            "disablePause enableExperimentalPause = \(IORecorder.enableExperimentalPause)"
        )
    }

    public func resumeRunning() {
        lockQueue.async {
            //print("Resume capture")
            self.isPaused = false
            //print("isPaused = \(self.isPaused)");
        }
    }

    public func stopRunning() {
        lockQueue.async {
            guard self.isRunning.value else {
                // TODO: potentally add in a safety check if writer not nil and is writing to mark as finished
                // in case the isRunning variable is not proper for some reason
                /*if self.writer != nil {
                 print("IORecorder stopRunning wtf but we saving to be safe!");
                 self.finishWriting()
                 self.isRunning.mutate { $0 = false }
                 }*/
                return
            }

            self.timeOffsetVideo = CMTime.zero
            self.timeOffsetAudio = CMTime.zero
            self.lastVideo = CMTime.zero
            self.lastAudio = CMTime.zero
            self.isPaused = false
            self.discontVideo = false
            self.discontAudio = false

            self.finishWriting()
            self.isRunning.mutate { $0 = false }
        }
    }
}
