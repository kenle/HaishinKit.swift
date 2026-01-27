Pod::Spec.new do |s|
  s.name         = 'HaishinKit'
  s.version      = '2.2.4.1'
  s.summary      = 'Camera and Microphone streaming library via RTMP, HLS for iOS.'
  s.description  = <<-DESC
HaishinKit is a Camera and Microphone streaming library via RTMP, HLS
for iOS, tvOS, macOS, and visionOS.
  DESC

  s.homepage     = 'https://github.com/shogo4405/HaishinKit.swift'
  s.license      = { :type => 'BSD' }
  s.author       = { 'shogo4405' => 'shogo4405@gmail.com' }

  s.source = {
    :git => 'https://github.com/kenle/HaishinKit.swift.git',
    :tag => s.version
  }

  s.swift_version = '5.7'
  s.ios.deployment_target = '15.0'

  # Silence Swift concurrency noise (SPM does this via swiftSettings)
  s.pod_target_xcconfig = {
    'SWIFT_STRICT_CONCURRENCY' => 'minimal'
  }

  # ---------------------------------------------------------
  # Core module (SPM target: HaishinKit)
  # Swift import: import HaishinKit
  # ---------------------------------------------------------
  s.subspec 'Core' do |core|
    core.source_files = 'HaishinKit/Sources/**/*.swift'
    core.dependency 'Logboard', '~> 2.6'
  end

  # ---------------------------------------------------------
  # RTMP module (SPM target: RTMPHaishinKit)
  # Swift import: import RTMPHaishinKit
  # ---------------------------------------------------------
  s.subspec 'RTMP' do |rtmp|
    rtmp.source_files = 'RTMPHaishinKit/Sources/**/*.swift'
    rtmp.dependency 'HaishinKit/Core'
  end

  # Default install gives Core only
  s.default_subspec = 'Core'
end