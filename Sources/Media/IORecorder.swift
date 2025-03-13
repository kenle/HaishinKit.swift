import AVFoundation

/// The interface an IORecorder uses to inform its delegate.
public protocol IORecorderDelegate: AnyObject {
    /// Tells the receiver to recorder error occured.
    func recorder(_ recorder: IORecorder, errorOccured error: IORecorder.Error)
    /// Tells the receiver to finish writing.
    func recorder(_ recorder: IORecorder, finishWriting writer: AVAssetWriter)
}

// MARK: -
/// The IORecorder class represents video and audio recorder.
public class IORecorder {
    private static let interpolationThreshold = 1024 * 4
    
    /// The IORecorder error domain codes.
    public enum Error: Swift.Error {
        /// Failed to create the AVAssetWriter.
        case failedToCreateAssetWriter(error: Swift.Error)
        /// Failed to append the PixelBuffer or SampleBuffer.
        case failedToAppend(error: Swift.Error?)
        /// Failed to finish writing the AVAssetWriter.
        case failedToFinishWriting(error: Swift.Error?)
    }
    
    /// The default output settings for an IORecorder.
    public static let defaultOutputSettings: [AVMediaType: [String: Any]] = [
        .audio: [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 0,
            AVNumberOfChannelsKey: 0
        ],
        .video: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoHeightKey: 0,
            AVVideoWidthKey: 0
        ]
    ]
    
    public var fileName: String?
    
    /// Specifies the delegate.
    public weak var delegate: IORecorderDelegate?
    /// Specifies the recorder settings.
    public var outputSettings: [AVMediaType: [String: Any]] = IORecorder.defaultOutputSettings
    /// The running indicies whether recording or not.
    public private(set) var isRunning: Atomic<Bool> = .init(false)
    public private(set) var isPaused: Atomic<Bool> = .init(false)
    public private(set) var discontAudio: Atomic<Bool> = .init(false)
    public private(set) var discontVideo: Atomic<Bool> = .init(false)
    public private(set) var enableExperimentalPause: Atomic<Bool> = .init(true)

    private var timeOffset = CMTime.zero
    private var lastVideo = CMTime.zero
    private var lastAudio = CMTime.zero
    
    public var movieFragmentInterval: Double? {
        didSet {
            if let movieFragmentInterval {
                self.movieFragmentInterval = max(10.0, movieFragmentInterval)
            }
        }
    }
    
    private let lockQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.IORecorder.lock")
    private var isReadyForStartWriting: Bool {
        guard let writer = writer else {
            return false
        }
        return outputSettings.count == writer.inputs.count
    }
    private var writer: AVAssetWriter?
    private var writerInputs: [AVMediaType: AVAssetWriterInput] = [:]
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var audioPresentationTime = CMTime.zero
    private var videoPresentationTime = CMTime.zero
    
#if os(iOS)
    private lazy var moviesDirectory: URL = {
        URL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0])
    }()
#else
    private lazy var moviesDirectory: URL = {
        URL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.moviesDirectory, .userDomainMask, true)[0])
    }()
#endif
    
    /// Append a sample buffer for recording.
    public func appendSampleBuffer(_ sampleBuffer: CMSampleBuffer, mediaType: AVMediaType) {
        lockQueue.async {
            if(self.enableExperimentalPause.value) {
                guard self.isRunning.value else {
                    return;
                }
                
                if (self.isPaused.value) {
                    //print("paused returning, appendSampleBuffer \(mediaType)");

                    return;
                }
                
                //print("appendSampleBuffer \(mediaType)");
                
                guard
                    let writer = self.writer,
                    let input = self.makeWriterInput(mediaType, sourceFormatHint: sampleBuffer.formatDescription),
                    self.isReadyForStartWriting else {
                    return
                }
                
                if self.discontAudio.value {
                    self.discontAudio.mutate { $0 = false }
                    self.timeOffset = CMTimeSubtract(CMSampleBufferGetPresentationTimeStamp(sampleBuffer), self.lastVideo)
                }
                
                let adjustedBuffer = self.timeOffset.value > 0 ? self.adjustTime(of: sampleBuffer, by: self.timeOffset) ?? sampleBuffer : sampleBuffer
                let pts = CMSampleBufferGetPresentationTimeStamp(adjustedBuffer)
                
                switch writer.status {
                case .unknown:
                    writer.startWriting()
                    writer.startSession(atSourceTime: adjustedBuffer.presentationTimeStamp)
                default:
                    break
                }
                
                // fix Local record audio desynchronization on camera switch
                if mediaType == .audio && self.audioPresentationTime != .zero {
                    if let adjustedBuffer = self.makeAudioCMSampleBuffer(adjustedBuffer), input.isReadyForMoreMediaData {
                        input.append(adjustedBuffer)
                        self.audioPresentationTime = CMTimeAdd(self.audioPresentationTime, adjustedBuffer.duration)
                    }
                }
                
                if input.isReadyForMoreMediaData {
                    switch mediaType {
                    case .audio:
                        self.lastAudio = pts
                        if input.append(adjustedBuffer) {
                            self.audioPresentationTime = adjustedBuffer.presentationTimeStamp
                        } else {
                            self.delegate?.recorder(self, errorOccured: .failedToAppend(error: writer.error))
                            
                        }
                    case .video:
                        self.lastVideo = pts
                        if input.append(adjustedBuffer) {
                            self.videoPresentationTime = adjustedBuffer.presentationTimeStamp
                        } else {
                            self.delegate?.recorder(self, errorOccured: .failedToAppend(error: writer.error))
                        }
                    default:
                        break
                    }
                }
            } else {
                guard
                    let writer = self.writer,
                    let input = self.makeWriterInput(mediaType, sourceFormatHint: sampleBuffer.formatDescription),
                    self.isReadyForStartWriting else {
                    return
                }
                
                //print("original appendSampleBuffer \(mediaType)");

                
                switch writer.status {
                case .unknown:
                    writer.startWriting()
                    writer.startSession(atSourceTime: sampleBuffer.presentationTimeStamp)
                default:
                    break
                }
                
                // fix Local record audio desynchronization on camera switch
                if mediaType == .audio && self.audioPresentationTime != .zero {
                    if let sampleBuffer = self.makeAudioCMSampleBuffer(sampleBuffer), input.isReadyForMoreMediaData {
                        input.append(sampleBuffer)
                        self.audioPresentationTime = CMTimeAdd(self.audioPresentationTime, sampleBuffer.duration)
                    }
                }
                
                if input.isReadyForMoreMediaData {
                    switch mediaType {
                    case .audio:
                        if input.append(sampleBuffer) {
                            self.audioPresentationTime = sampleBuffer.presentationTimeStamp
                        } else {
                            self.delegate?.recorder(self, errorOccured: .failedToAppend(error: writer.error))
                        }
                    case .video:
                        if input.append(sampleBuffer) {
                            self.videoPresentationTime = sampleBuffer.presentationTimeStamp
                        } else {
                            self.delegate?.recorder(self, errorOccured: .failedToAppend(error: writer.error))
                        }
                    default:
                        break
                    }
                }
            }
        }
    }
    
    /// Append a pixel buffer for recording.
    public func appendPixelBuffer(_ pixelBuffer: CVPixelBuffer, withPresentationTime: CMTime) {
        lockQueue.async {
            //print("appendPixelBuffer, isPaused =\(self.isPaused.value), enableExperimentalPause=\(self.enableExperimentalPause.value)");
            if self.enableExperimentalPause.value {
                guard self.isRunning.value else {
                    return;
                }
                
                if(self.isPaused.value) {
                    //print("paused returning, appendPixelBuffer");
                    return
                }

                //print("appendPixelBuffer");

                guard
                    let writer = self.writer,
                    let input = self.makeWriterInput(.video, sourceFormatHint: CMVideoFormatDescription.create(pixelBuffer: pixelBuffer)),
                    let adaptor = self.makePixelBufferAdaptor(input),
                    self.isReadyForStartWriting else {
                    return
                }

                if self.discontVideo.value {
                    self.discontVideo.mutate { $0 = false }
                    self.timeOffset = CMTimeSubtract(withPresentationTime, self.lastVideo)
                }

                let adjustedPresentationTime = self.timeOffset.value > 0 ? CMTimeSubtract(withPresentationTime, self.timeOffset) : withPresentationTime

                switch writer.status {
                case .unknown:
                    writer.startWriting()
                    writer.startSession(atSourceTime: adjustedPresentationTime)
                default:
                    break
                }

                if input.isReadyForMoreMediaData {
                    if adaptor.append(pixelBuffer, withPresentationTime: adjustedPresentationTime) {
                        self.videoPresentationTime = adjustedPresentationTime
                        self.lastVideo = adjustedPresentationTime
                    } else {
                        self.delegate?.recorder(self, errorOccured: .failedToAppend(error: writer.error))
                    }
                }
            } else {
                guard
                    let writer = self.writer,
                    let input = self.makeWriterInput(.video, sourceFormatHint: CMVideoFormatDescription.create(pixelBuffer: pixelBuffer)),
                    let adaptor = self.makePixelBufferAdaptor(input),
                    self.isReadyForStartWriting && self.videoPresentationTime.seconds < withPresentationTime.seconds else {
                    return
                }

                //print("original appendPixelBuffer");

                switch writer.status {
                case .unknown:
                    writer.startWriting()
                    writer.startSession(atSourceTime: withPresentationTime)
                default:
                    break
                }

                if input.isReadyForMoreMediaData {
                    if adaptor.append(pixelBuffer, withPresentationTime: withPresentationTime) {
                        self.videoPresentationTime = withPresentationTime
                    } else {
                        self.delegate?.recorder(self, errorOccured: .failedToAppend(error: writer.error))
                    }
                }
            }
        }
    }
    
    func finishWriting() {
        guard let writer = writer else {
            delegate?.recorder(self, errorOccured: .failedToFinishWriting(error: nil))
            return
        }
        
        print("Finishing writing original, writer status: \(writer.status.rawValue)")
        
        guard writer.status == .writing else {
            delegate?.recorder(self, errorOccured: .failedToFinishWriting(error: writer.error))
            return
        }
        
        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()
        for (_, input) in writerInputs {
            input.markAsFinished()
        }
        writer.finishWriting {
            print("Finish writing original complete, writer status: \(writer.status.rawValue), error: \(String(describing: writer.error))")
            self.delegate?.recorder(self, finishWriting: writer)
            self.writer = nil
            self.writerInputs.removeAll()
            self.pixelBufferAdaptor = nil
            dispatchGroup.leave()
        }
        dispatchGroup.wait()
    }
    
    
    /*
     func finishWriting() {
     guard let writer = writer else {
     delegate?.recorder(self, errorOccured: .failedToFinishWriting(error: nil))
     return
     }
     
     print("Finishing writing 3.4, writer status: \(writer.status.rawValue)")
     
     // Attempt to mark inputs as finished, regardless of writer status
     let dispatchGroup = DispatchGroup()
     dispatchGroup.enter()
     
     for (_, input) in writerInputs {
     input.markAsFinished()
     }
     
     if writer.status == .writing {
     writer.finishWriting {
     print("Finish writing complete 3.4, writer status: \(writer.status.rawValue), error: \(String(describing: writer.error))")
     self.delegate?.recorder(self, finishWriting: writer)
     self.writer = nil
     self.writerInputs.removeAll()
     self.pixelBufferAdaptor = nil
     dispatchGroup.leave()
     }
     } else {
     print("Finish writing something went wrong but trying to save anyway complete 3.4, writer status: \(writer.status.rawValue), error: \(String(describing: writer.error))")
     self.delegate?.recorder(self, finishWriting: writer)
     self.writer = nil
     self.writerInputs.removeAll()
     self.pixelBufferAdaptor = nil
     dispatchGroup.leave()
     }
     dispatchGroup.wait()
     }*/
    
    
    
    private func makeWriterInput(_ mediaType: AVMediaType, sourceFormatHint: CMFormatDescription?) -> AVAssetWriterInput? {
        guard writerInputs[mediaType] == nil else {
            return writerInputs[mediaType]
        }
        var outputSettings: [String: Any] = [:]
        if let defaultOutputSettings: [String: Any] = self.outputSettings[mediaType] {
            switch mediaType {
            case .audio:
                guard
                    let format = sourceFormatHint,
                    let inSourceFormat = format.streamBasicDescription?.pointee else {
                    break
                }
                for (key, value) in defaultOutputSettings {
                    switch key {
                    case AVSampleRateKey:
                        outputSettings[key] = AnyUtil.isZero(value) ? inSourceFormat.mSampleRate : value
                    case AVNumberOfChannelsKey:
                        outputSettings[key] = AnyUtil.isZero(value) ? Int(inSourceFormat.mChannelsPerFrame) : value
                    default:
                        outputSettings[key] = value
                    }
                }
            case .video:
                guard let format = sourceFormatHint else {
                    break
                }
                for (key, value) in defaultOutputSettings {
                    switch key {
                    case AVVideoHeightKey:
                        outputSettings[key] = AnyUtil.isZero(value) ? Int(format.dimensions.height) : value
                    case AVVideoWidthKey:
                        outputSettings[key] = AnyUtil.isZero(value) ? Int(format.dimensions.width) : value
                    default:
                        outputSettings[key] = value
                    }
                }
            default:
                break
            }
        }
        
        let input = AVAssetWriterInput(mediaType: mediaType, outputSettings: outputSettings, sourceFormatHint: sourceFormatHint)
        input.expectsMediaDataInRealTime = true
        writerInputs[mediaType] = input
        writer?.add(input)
        
        return input
    }
    
    private func makePixelBufferAdaptor(_ writerInput: AVAssetWriterInput?) -> AVAssetWriterInputPixelBufferAdaptor? {
        guard pixelBufferAdaptor == nil else {
            return pixelBufferAdaptor
        }
        guard let writerInput = writerInput else {
            return nil
        }
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writerInput, sourcePixelBufferAttributes: [:])
        pixelBufferAdaptor = adaptor
        return adaptor
    }
    
    private func makeAudioCMSampleBuffer(_ buffer: CMSampleBuffer) -> CMSampleBuffer? {
        let numSamples = Int((buffer.presentationTimeStamp.seconds - self.audioPresentationTime.seconds) * Double(buffer.presentationTimeStamp.timescale))
        
        guard Self.interpolationThreshold <= numSamples else {
            return nil
        }
        
        var status: OSStatus = noErr
        var sampleBuffer: CMSampleBuffer?
        
        var timing = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: buffer.duration.timescale),
            presentationTimeStamp: audioPresentationTime,
            decodeTimeStamp: CMTime.invalid
        )
        
        status = CMSampleBufferCreate(
            allocator: kCFAllocatorDefault,
            dataBuffer: nil,
            dataReady: false,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: buffer.formatDescription,
            sampleCount: numSamples,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timing,
            sampleSizeEntryCount: 0,
            sampleSizeArray: nil,
            sampleBufferOut: &sampleBuffer
        )
        
        guard
            let sampleBuffer = sampleBuffer,
            let formatDescription = sampleBuffer.formatDescription, status == noErr else {
            return nil
        }
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: AVAudioFormat(cmAudioFormatDescription: formatDescription), frameCapacity: AVAudioFrameCount(numSamples)) else {
            return nil
        }
        buffer.frameLength = buffer.frameCapacity
        
        status = CMSampleBufferSetDataBufferFromAudioBufferList(
            sampleBuffer,
            blockBufferAllocator: kCFAllocatorDefault,
            blockBufferMemoryAllocator: kCFAllocatorDefault,
            flags: 0,
            bufferList: buffer.audioBufferList
        )
        
        guard status == noErr else {
            return nil
        }
        
        return sampleBuffer
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
                let url = self.moviesDirectory.appendingPathComponent(fileName).appendingPathExtension("mp4")
                self.writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
                if let movieFragmentInterval = self.movieFragmentInterval {
                    self.writer?.movieFragmentInterval = CMTime(seconds: movieFragmentInterval, preferredTimescale: 1)
                }
                self.isPaused.mutate { $0 = false }
                self.timeOffset = .zero
                self.discontVideo.mutate { $0 = false }
                self.discontAudio.mutate { $0 = false }
                self.isRunning.mutate { $0 = true }
            } catch {
                self.delegate?.recorder(self, errorOccured: .failedToCreateAssetWriter(error: error))
            }
        }
    }
    
    public func pauseRunning() {
        lockQueue.async {
            print("Pausing capture")
            
            self.isPaused.mutate { $0 = true }
            self.discontVideo.mutate { $0 = true }
            self.discontAudio.mutate { $0 = true }
            
            print("isPaused = \(self.isPaused.value)");
        }
    }
    
    public func enablePause() {
        lockQueue.async {
            self.enableExperimentalPause.mutate { $0 = true }
            print("enablePause enableExperimentalPause = \(self.enableExperimentalPause.value)");
        }
    }
    
    public func disablePause() {
        lockQueue.async {
            self.enableExperimentalPause.mutate { $0 = false }

            print("disablePause enableExperimentalPause = \(self.enableExperimentalPause.value)");
        }
    }
    
    public func resumeRunning() {
        lockQueue.async {
            print("Resume capture")
            self.isPaused.mutate { $0 = false }
            print("isPaused = \(self.isPaused.value)");
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
            self.finishWriting()
            self.isRunning.mutate { $0 = false }
        }
    }
}
