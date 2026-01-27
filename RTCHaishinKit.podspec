Pod::Spec.new do |s|
  s.name         = "RTCHaishinKit"
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
  s.ios.deployment_target = "15.0"

  # WebRTC
  s.subspec "RTCHaishinKit" do |ss|
    ss.source_files = "RTCHaishinKit/Sources/**/*.{swift,h}"
    ss.vendored_frameworks = "https://github.com/HaishinKit/libdatachannel-xcframework/releases/download/v0.24.0/libdatachannel.xcframework.zip"
    ss.dependency "HaishinKit"
  end
end