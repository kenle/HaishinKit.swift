Pod::Spec.new do |s|
  s.name             = 'HaishinKit'
  s.version          = '2.2.4.1'
  s.summary          = 'Camera and Microphone streaming library via RTMP, HLS for iOS, macOS, tvOS and visionOS.'
  s.homepage         = 'https://github.com/shogo4405/HaishinKit.swift'
  s.license          = { :type => 'BSD', :file => 'LICENSE' }
  s.author           = { 'shogo4405' => 'shogo4405@gmail.com' }
  s.source           = { :git => 'https://github.com/kenle/HaishinKit.swift.git', :tag => s.version.to_s }
  s.swift_version    = '5.9'
  s.cocoapods_version = '>= 1.13.0'

  s.ios.deployment_target     = '15.0'

  # Silence Swift concurrency warnings (matches SPM behavior)
  s.pod_target_xcconfig = {
    'SWIFT_STRICT_CONCURRENCY' => 'minimal'
  }

  # Core library - always included
  s.source_files = 'HaishinKit/Sources/**/*.{swift,h,m,c}'

  s.dependency 'Logboard', '~> 2.6'

  # === Extension modules as separate subspecs (exactly matching SPM products) ===

  s.subspec 'RTMPHaishinKit' do |rtmp|
    rtmp.source_files = 'RTMPHaishinKit/Sources/**/*.{swift,h,m,c}'
    rtmp.dependency 'HaishinKit'
  end

  s.subspec 'SRTHaishinKit' do |srt|
    srt.source_files = 'SRTHaishinKit/Sources/**/*.{swift,h,m,c}'
    srt.dependency 'HaishinKit'
    srt.vendored_frameworks = 'libsrt.xcframework'
  end

  s.subspec 'MoQTHaishinKit' do |moqt|
    moqt.source_files = 'MoQTHaishinKit/Sources/**/*.{swift,h,m,c}'
    moqt.dependency 'HaishinKit'
  end

  s.subspec 'RTCHaishinKit' do |rtc|
    rtc.source_files = 'RTCHaishinKit/Sources/**/*.{swift,h,m,c}'
    rtc.dependency 'HaishinKit'
    rtc.vendored_frameworks = 'libdatachannel.xcframework'
  end

  # Default: only core (same behavior as SPM when you do pod 'HaishinKit')
  s.default_subspec = 'Core'

  # Explicit Core subspec so people can do pod 'HaishinKit/Core' if they want
  s.subspec 'Core' do |core|
    # No extra files — everything is already in s.source_files above
  end
end