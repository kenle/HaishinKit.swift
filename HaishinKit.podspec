Pod::Spec.new do |s|
  s.name         = 'HaishinKit'
  s.version      = '2.2.4.2'   # update to '2.2.4.2' for the new tag
  s.summary      = 'Camera and Microphone streaming library via RTMP, HLS, etc.'
  s.homepage     = 'https://github.com/kenle/HaishinKit.swift'
  s.license      = { :type => 'BSD', :file => 'LICENSE.md' }
  s.author       = { 'Your Name' => 'your@email.com' }

  # ── This is the critical line that's missing or broken ──
  s.source       = { :git => 'https://github.com/kenle/HaishinKit.swift.git', :tag => s.version.to_s }

  s.swift_versions = ['5.7', '5.8', '5.9']
  s.ios.deployment_target = '15.0'

  # Core sources (adjust paths if needed)
  s.source_files = 'HaishinKit/Sources/**/*.swift'

  # If you have subspecs (recommended for RTMPHaishinKit)
  s.subspec 'RTMPHaishinKit' do |ss|
    ss.source_files = 'RTMPHaishinKit/Sources/**/*.swift'
    ss.dependency 'HaishinKit'   # pulls core
  end

  # ... add other subspecs like SRT/MoQT/RTC if needed
end