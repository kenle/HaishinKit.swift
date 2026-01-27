Pod::Spec.new do |s|
  s.name             = 'RTCHaishinKit'
  s.version          = '2.2.4.8'  # Must match the core version/tag
  s.summary          = 'WebRTC extension for HaishinKit'
  s.description      = <<-DESC
                       RTCHaishinKit provides WebRTC-based streaming and connectivity
                       built on top of HaishinKit core.
                       DESC
  s.homepage         = 'https://github.com/kenle/HaishinKit.swift'
  s.license          = { :type => 'BSD', :file => 'LICENSE' }
  s.author           = { 'shogo4405' => 'shogo4405@gmail.com' }
  s.source           = { :git => 'https://github.com/kenle/HaishinKit.swift.git', :tag => s.version.to_s }

  s.swift_versions   = ['5.7', '5.8', '5.9', '6.0']
  s.ios.deployment_target     = '15.0'
  s.tvos.deployment_target    = '15.0'
  s.macos.deployment_target   = '12.0'
  s.visionos.deployment_target = '1.0'

  s.pod_target_xcconfig = {
    'SWIFT_STRICT_CONCURRENCY' => 'minimal'
  }

  s.source_files          = 'RTCHaishinKit/Sources/**/*.{swift,h,m,c}'
  s.vendored_frameworks   = 'libdatachannel.xcframework'  # Adjust path if it's in a subfolder, e.g. 'Vendor/WebRTC/libdatachannel.xcframework'

  s.dependency            'HaishinKit', "= #{s.version}"
end