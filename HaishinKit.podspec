Pod::Spec.new do |s|
  s.name         = "HaishinKit"
  s.version      = "2.2.4"
  s.summary      = "Camera and Microphone streaming library via RTMP, HLS, WebRTC, SRT for iOS, macOS, tvOS, and visionOS."
  s.description  = <<-DESC
HaishinKit. Camera and Microphone streaming library supporting multiple protocols:
RTMP, HLS, WebRTC, SRT, and MoQT. Supports iOS, macOS, tvOS, Mac Catalyst, and visionOS.
  DESC
  s.homepage     = "https://github.com/shogo4405/HaishinKit.swift"
  s.license      = { :type => "BSD-3-Clause" }
  s.author       = { "shogo4405" => "shogo4405@gmail.com" }
  s.swift_version = "6.0"

  # Deployment targets
  s.ios.deployment_target       = "15.0"
  s.osx.deployment_target       = "12.0"
  s.tvos.deployment_target      = "15.0"
  s.maccatalyst.deployment_target = "15.0"
  s.visionos.deployment_target  = "1.0"

  # Core HaishinKit
  s.subspec "HaishinKit" do |ss|
    ss.source_files = "HaishinKit/Sources/**/*.{swift,h}"
    ss.dependency 'Logboard', '~> 2.6'
  end

  # RTMP
  s.subspec "RTMPHaishinKit" do |ss|
    ss.source_files = "RTMPHaishinKit/Sources/**/*.{swift,h}"
    ss.dependency "HaishinKit"
  end

  # SRT
  s.subspec "SRTHaishinKit" do |ss|
    ss.source_files = "SRTHaishinKit/Sources/**/*.{swift,h}"
    ss.vendored_frameworks = "https://github.com/HaishinKit/libsrt-xcframework/releases/download/v1.5.4/libsrt.xcframework.zip"
    ss.dependency "HaishinKit"
  end

  # MoQT
  s.subspec "MoQTHaishinKit" do |ss|
    ss.source_files = "MoQTHaishinKit/Sources/**/*.{swift,h}"
    ss.dependency "HaishinKit"
  end

  # WebRTC
  s.subspec "RTCHaishinKit" do |ss|
    ss.source_files = "RTCHaishinKit/Sources/**/*.{swift,h}"
    ss.vendored_frameworks = "https://github.com/HaishinKit/libdatachannel-xcframework/releases/download/v0.24.0/libdatachannel.xcframework.zip"
    ss.dependency "HaishinKit"
  end
end
