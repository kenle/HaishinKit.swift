Pod::Spec.new do |s|
  s.name             = 'HaishinKit'
  s.version          = '2.2.4.3'
  s.summary          = 'Camera and Microphone streaming library via RTMP, HLS, SRT for iOS, tvOS, macOS, visionOS'
  s.homepage         = 'https://github.com/kenle/HaishinKit.swift'
  s.license          = { :type => 'BSD', :file => 'LICENSE.md' }
  s.author           = { 'shogo4405' => 'shogo4405@gmail.com' }  # or your info
  s.source           = { :git => 'https://github.com/kenle/HaishinKit.swift.git', :tag => s.version.to_s }

  s.swift_versions   = ['5.7', '5.8', '5.9', '6.0']
  s.ios.deployment_target     = '15.0'
  s.tvos.deployment_target    = '15.0'
  s.macos.deployment_target   = '12.0'
  s.visionos.deployment_target = '1.0'

  s.pod_target_xcconfig = { 'SWIFT_STRICT_CONCURRENCY' => 'minimal' }

  # Core files (included when pod 'HaishinKit' is installed)
  s.source_files = 'HaishinKit/Sources/**/*.{swift,h,m,c}'

  s.dependency 'Logboard', '~> 2.6'

  # Subs specs – inherit core automatically, no parent dep needed
  s.subspec 'RTMPHaishinKit' do |ss|
    ss.source_files = 'RTMPHaishinKit/Sources/**/*.{swift,h,m,c}'
  end

  s.subspec 'SRTHaishinKit' do |ss|
    ss.source_files = 'SRTHaishinKit/Sources/**/*.{swift,h,m,c}'
    ss.vendored_frameworks = 'Vendor/SRT/libsrt.xcframework'  # adjust path if needed
  end

  # Add similar for MoQTHaishinKit, RTCHaishinKit if you want them installable separately
  # ...

  s.default_subspec = nil  # or 'Core' if you want to force core-only by default
end