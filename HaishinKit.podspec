Pod::Spec.new do |s|
  s.name             = 'HaishinKit'
  s.version          = '2.2.4.8'   # Bump version for the new setup (or use 2.2.4.3 if you prefer, but new tag recommended)
  s.summary          = 'Camera and Microphone streaming library core via RTMP, HLS, SRT for iOS, tvOS, macOS, visionOS.'
  s.description      = <<-DESC
                       HaishinKit core framework (shared utilities, camera, audio handling).
                       DESC
  s.homepage         = 'https://github.com/kenle/HaishinKit.swift'
  s.license          = { :type => 'BSD', :file => 'LICENSE' }
  s.author           = { 'shogo4405' => 'shogo4405@gmail.com' }  # or your details

  s.source           = { :git => 'https://github.com/kenle/HaishinKit.swift.git', :tag => s.version.to_s }

  s.swift_versions   = ['5.7', '5.8', '5.9', '6.0']
  s.ios.deployment_target     = '15.0'
  s.tvos.deployment_target    = '15.0'
  s.macos.deployment_target   = '12.0'
  s.visionos.deployment_target = '1.0'

  s.pod_target_xcconfig = {
    'SWIFT_STRICT_CONCURRENCY' => 'minimal'
  }

  # Core sources only
  s.source_files = 'HaishinKit/Sources/**/*.{swift,h,m,c}'

  s.dependency 'Logboard', '~> 2.6.1'
end