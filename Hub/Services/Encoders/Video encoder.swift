//
//  VideoCompressor.swift
//  Hub
//
//  Created by Linux on 19.07.25.
//

import Foundation
@preconcurrency import AVFoundation
import VideoToolbox

public actor VideoEncoder {
  public enum Error: Swift.Error {
    case noVideo, writingError
  }
  
  // Compression Encode Parameters
  public struct EncoderSettings: Sendable {
    public static func h264(bitrate: Int = 1_000_000, size: CGSize? = nil, maxKeyframeInterval: Int = 10, frameReordering: Bool = true, profile: H264.ProfileLevel = .highAuto, entropy: H264.Entropy = .cabac) -> Self {
      let settings = VideoCompressorSettings()
        .codec(.h264)
        .compression(bitrate: Float(bitrate), frameReordering: frameReordering, profile: profile, entropy: entropy)
        .keyframeInterval(maxKeyframeInterval)
      var config = EncoderSettings(settings: settings, fileType: .mp4, size: size)
      config.bitrate = Float(bitrate)
      return config
    }
    public static func hevc(quality: Float, size: CGSize?, frameReordering: Bool, profile: Hevc.ProfileLevel = .main) -> Self {
      other(codec: .hevc, quality: quality, size: size, frameReordering: frameReordering)
    }
    public static func other(codec: AVVideoCodecType, quality: Float, size: CGSize?, frameReordering: Bool = true, profile: Hevc.ProfileLevel = .main) -> Self {
      let settings = VideoCompressorSettings()
        .codec(codec)
        .compression(quality: quality, frameReordering: frameReordering, profile: profile)
      var config = EncoderSettings(settings: settings, fileType: .mov, size: size)
      config.quality = quality
      return config
    }
    
    public var settings: VideoCompressorSettings
    public var fileType: AVFileType
    public var size: CGSize?
    var bitrate: Float?
    var quality: Float?
    init(settings: VideoCompressorSettings, fileType: AVFileType, size: CGSize?) {
      self.settings = settings
      self.fileType = fileType
      self.size = size
    }
  }
  public init() { }
  
  struct AudioTrack {
    let track: AVAssetTrack
    let dataRate: Float
    var settings: [String: Any] {
      var audioChannelLayout = AudioChannelLayout()
      memset(&audioChannelLayout, 0, MemoryLayout<AudioChannelLayout>.size)
      audioChannelLayout.mChannelLayoutTag = kAudioChannelLayoutTag_Stereo
      return [
        AVFormatIDKey: kAudioFormatMPEG4AAC,
        AVSampleRateKey: 44100,
        AVEncoderBitRateKey: min(dataRate, 128_000),
        AVNumberOfChannelsKey: 2,
        AVChannelLayoutKey: Data(bytes: &audioChannelLayout, count: MemoryLayout<AudioChannelLayout>.size)
      ]
    }
  }
  
  
  public func encode(from asset: AVAsset, to: URL, settings: EncoderSettings, progress: @escaping @Sendable @MainActor (CMTime, CMTime) -> Void) async throws {
    guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else { throw Error.noVideo }
    
    let (videoSize, transform) = try await videoTrack.load(.naturalSize, .preferredTransform)
    let targetSize = mapSize(settings.size, size: videoSize)
    let videoSettings = settings.settings.width(targetSize.width).height(targetSize.height).settings
    let audio: AudioTrack?
    if let track = try await asset.loadTracks(withMediaType: .audio).first {
      let dataRate = try await track.load(.estimatedDataRate)
      audio = AudioTrack(track: track, dataRate: dataRate)
    } else {
      audio = nil
    }
    
    let duration: CMTime = try await asset.load(.duration)
    let progress = CompressionProgress(duration: duration, callback: progress)
    
    let videoOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
    let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
    videoInput.transform = transform
    let reader = try AVAssetReader(asset: asset)
    let writer = try AVAssetWriter(url: to, fileType: settings.fileType)
    if reader.canAdd(videoOutput) {
      reader.add(videoOutput)
      videoOutput.alwaysCopiesSampleData = false
    }
    if writer.canAdd(videoInput) {
      writer.add(videoInput)
    }
    
    var audioInput: AVAssetWriterInput?
    var audioOutput: AVAssetReaderTrackOutput?
    if let audio {
      audioOutput = AVAssetReaderTrackOutput(track: audio.track, outputSettings: [AVFormatIDKey: kAudioFormatLinearPCM, AVNumberOfChannelsKey: 2])
      audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audio.settings)
    }
    if let audioOutput, reader.canAdd(audioOutput) {
      reader.add(audioOutput)
    }
    if let audioInput, writer.canAdd(audioInput) {
      writer.add(audioInput)
    }
    
    reader.startReading()
    writer.startWriting()
    writer.startSession(atSourceTime: CMTime.zero)
    async let videoTask: Void = process(input: videoInput, output: videoOutput, progress: progress)
    async let audioTask: Void = process(input: audioInput, output: audioOutput, progress: nil)
    await videoTask
    await audioTask
    switch writer.status {
    case .writing, .completed:
      await withCheckedContinuation { continuation in
        writer.finishWriting {
          continuation.resume()
        }
      }
    default:
      throw writer.error ?? Error.writingError
    }
  }
  
  
  private func process(input: AVAssetWriterInput?, output: AVAssetReaderOutput?, progress: CompressionProgress?) async {
    guard let input, let output else { return }
    await withCheckedContinuation { continuation in
      input.requestMediaDataWhenReady(on: .global()) {
        while input.isReadyForMoreMediaData {
          if let buffer = output.copyNextSampleBuffer() {
            if let progress {
              let time = CMSampleBufferGetPresentationTimeStamp(buffer)
              Task { @MainActor in
                progress.send(progress: time)
              }
            }
            input.append(buffer)
          } else {
            input.markAsFinished()
            continuation.resume()
            return
          }
        }
      }
    }
  }
  func mapSize(_ target: CGSize?, size: CGSize) -> CGSize {
    guard let target else { return size }
    if target.width == -1 && target.height == -1 {
      return size
    } else if target.width != -1 && target.height != -1 {
      return target
    } else if target.width == -1 {
      let width = target.height * size.width / size.height
      return CGSize(width: width.rounded(.down), height: target.height)
    } else {
      let height = target.width * size.height / size.width
      return CGSize(width: target.width, height: height.rounded(.down))
    }
  }
}

private struct CompressionProgress: Sendable {
  var duration: CMTime
  let callback: @Sendable @MainActor (CMTime, CMTime) -> ()
  @MainActor
  func send(progress: CMTime) {
    callback(duration, progress)
  }
}

public struct VideoCompressorSettings: @unchecked Sendable {
  public var settings: [String: Any] = [:]
  public init(settings: [String : Any] = [:]) {
    self.settings = settings
  }
}
public extension VideoCompressorSettings {
  func codec(_ value: AVVideoCodecType) -> Self {
    set(AVVideoCodecKey, value)
  }
  func scaling(_ value: ScalingMode) -> Self {
    set(AVVideoScalingModeKey, value.rawValue)
  }
  func width(_ value: Double) -> Self {
    set(AVVideoWidthKey, value.rounded(.down))
  }
  func height(_ value: Double) -> Self {
    set(AVVideoHeightKey, value.rounded(.down))
  }
  func wideColor(_ value: Bool = true) -> Self {
    set(AVVideoAllowWideColorKey, value)
  }
  func pixelAspectRatio(horizontal: Double = 1, vertical: Double = 1) -> Self {
    set(AVVideoPixelAspectRatioKey, [
      AVVideoPixelAspectRatioHorizontalSpacingKey: horizontal,
      AVVideoPixelAspectRatioVerticalSpacingKey: vertical
    ])
  }
  func cleanAperture(frame: CGRect) -> Self {
    set(AVVideoCleanApertureKey, [
      AVVideoCleanApertureWidthKey: frame.width,
      AVVideoCleanApertureHeightKey: frame.height,
      AVVideoCleanApertureHorizontalOffsetKey: frame.minX,
      AVVideoCleanApertureVerticalOffsetKey: frame.minY,
    ])
  }
  func color(_ value: Color) -> Self {
    set(AVVideoColorPropertiesKey, value.rawValue)
  }
  func allowFrameReordering(_ value: Bool) -> Self {
    set(AVVideoAllowFrameReorderingKey, value)
  }
  func compression(bitrate: Float, frameReordering: Bool, profile: H264.ProfileLevel = .highAuto, entropy: H264.Entropy = .cabac) -> Self {
    compression {
      $0[AVVideoAverageBitRateKey] = bitrate
      $0[AVVideoAllowFrameReorderingKey] = frameReordering
      $0[AVVideoProfileLevelKey] = profile.rawValue
      $0[AVVideoH264EntropyModeKey] = entropy.rawValue
    }
  }
  func compression(quality: Float, frameReordering: Bool, profile: Hevc.ProfileLevel = .main) -> Self {
    compression {
      $0[AVVideoQualityKey] = quality
      $0[AVVideoAllowFrameReorderingKey] = frameReordering
      $0[AVVideoProfileLevelKey] = profile.rawValue
    }
  }
  func keyframeInterval(_ value: Int) -> Self {
    compression { $0[AVVideoMaxKeyFrameIntervalKey] = value }
  }
  func expectedFramerate(_ value: Float) -> Self {
    compression { $0[AVVideoExpectedSourceFrameRateKey] = value }
  }
  func nonDroppableFramerate(_ value: Float) -> Self {
    compression { $0[AVVideoAverageNonDroppableFrameRateKey] = value }
  }
  private func compression(_ edit: (inout [String: Any]) -> ()) -> Self {
    var settings = settings
    var compression: [String: Any] = settings[AVVideoCompressionPropertiesKey] as? [String: Any] ?? [:]
    edit(&compression)
    settings[AVVideoCompressionPropertiesKey] = compression
    return VideoCompressorSettings(settings: settings)
  }
  
  private func set(_ key: String, _ value: Any) -> Self {
    var compressor = self
    compressor.settings[key] = value
    return compressor
  }
  enum ScalingMode {
    case fit, resize, aspectFit, aspectFill
    var rawValue: String {
      switch self {
      case .fit: return AVVideoScalingModeFit
      case .resize: return AVVideoScalingModeResize
      case .aspectFit: return AVVideoScalingModeResizeAspect
      case .aspectFill: return AVVideoScalingModeResizeAspectFill
      }
    }
  }
  enum Color {
    case hd, sd, wideGamut, wideGamut10Bit
    @available(iOS 16.0, macOS 13.0, tvOS 16.0, *)
    case hdrLinear
    var rawValue: [String: String] {
      switch self {
      case .hd:
        return [
          AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
          AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
          AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
        ]
      case .sd:
        return [
          AVVideoColorPrimariesKey: AVVideoColorPrimaries_SMPTE_C,
          AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
          AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_601_4,
        ]
      case .wideGamut:
        return [
          AVVideoColorPrimariesKey: AVVideoColorPrimaries_P3_D65,
          AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
          AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
        ]
      case .wideGamut10Bit:
        return [
          AVVideoColorPrimariesKey: AVVideoColorPrimaries_P3_D65,
          AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_2100_HLG,
          AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
        ]
      case .hdrLinear:
        if #available(iOS 16.0, macOS 13.0, tvOS 16.0, *) {
          return [
            AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_2020,
            AVVideoTransferFunctionKey: AVVideoTransferFunction_Linear,
            AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_2020,
          ]
        } else {
          return [
            AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_2020,
            AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_2100_HLG,
            AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_2020,
          ]
        }
      }
    }
  }
}

public enum Hevc {
  public enum ProfileLevel {
    case main, main10, main42210
    var rawValue: String {
      switch self {
      case .main: return kVTProfileLevel_HEVC_Main_AutoLevel as String
      case .main10: return kVTProfileLevel_HEVC_Main10_AutoLevel as String
      case .main42210: if #available(iOS 15.4, macOS 12.3, tvOS 15.4, *) {
        return kVTProfileLevel_HEVC_Main42210_AutoLevel as String
      } else {
        return kVTProfileLevel_HEVC_Main10_AutoLevel as String
      }
      }
    }
  }
}

public enum H264 {
  public enum ProfileLevel {
    case baseline30, baseline31, baseline41, baselineAuto
    case main30, main31, main32, main41, mainAuto
    case high40, high41, highAuto
    
    var rawValue: String {
      switch self {
      case .baseline30: return AVVideoProfileLevelH264Baseline30
      case .baseline31: return AVVideoProfileLevelH264Baseline31
      case .baseline41: return AVVideoProfileLevelH264Baseline41
      case .baselineAuto: return AVVideoProfileLevelH264BaselineAutoLevel
      case .main30: return AVVideoProfileLevelH264Main30
      case .main31: return AVVideoProfileLevelH264Main31
      case .main32: return AVVideoProfileLevelH264Main32
      case .main41: return AVVideoProfileLevelH264Main41
      case .mainAuto: return AVVideoProfileLevelH264MainAutoLevel
      case .high40: return AVVideoProfileLevelH264High40
      case .high41: return AVVideoProfileLevelH264High41
      case .highAuto: return AVVideoProfileLevelH264HighAutoLevel
      }
    }
  }
  public enum Entropy {
    case cavlc, cabac
    var rawValue: String {
      switch self {
      case .cavlc: return AVVideoH264EntropyModeCAVLC
      case .cabac: return AVVideoH264EntropyModeCABAC
      }
    }
  }
}
