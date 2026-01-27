Pod::Spec.new do |s|
  s.name             = 'MoQTHaishinKit'
  s.version          = '2.2.4.8'  # Must match the core version/tag
  s.summary          = 'MoQT streaming extension for HaishinKit'
  s.description      = <<-DESC
                       MoQTHaishinKit provides MoQT (Media over QUIC Transport) capabilities
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

  s.source_files     = 'MoQTHaishinKit/Sources/**/*.{swift,h,m,c}'
  s.dependency       'HaishinKit', "= #{s.version}"
end