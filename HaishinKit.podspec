Pod::Spec.new do |s|
  s.name = 'HaishinKit'
  s.version = '2.2.4.1'
  s.summary = 'Camera and Microphone streaming library'
  s.swift_version = '5.7'

  s.homepage = 'https://github.com/kenle/HaishinKit.swift'
  s.license = { :type => 'BSD' }
  s.author = { 'shogo4405' => 'shogo4405@gmail.com' }
  s.source = { :git => 'https://github.com/kenle/HaishinKit.swift.git', :tag => s.version.to_s }

  s.ios.deployment_target = '12.0'

  # Pick the modules you actually need
  s.source_files = [
    'HaishinKit/**/*.swift',
    'RTMPHaishinKit/**/*.swift'
  ]

  s.dependency 'Logboard'
end