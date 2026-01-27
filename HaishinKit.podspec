Pod::Spec.new do |s|
  s.name          = "HaishinKit"
  s.version       = "2.2.4.1"
  s.summary       = "Camera and Microphone streaming library via RTMP, HLS for iOS, macOS and tvOS."
  s.swift_version = "5.7"

  s.description  = <<-DESC
  HaishinKit. Camera and Microphone streaming library via RTMP, HLS for iOS, macOS and tvOS.
  DESC

  s.homepage     = "https://github.com/shogo4405/HaishinKit.swift"
  s.license      = "New BSD"
  s.author       = { "shogo4405" => "shogo4405@gmail.com" }
  s.authors      = { "shogo4405" => "shogo4405@gmail.com" }
  s.source       = { :git => "https://github.com/kenle/HaishinKit.swift.git", :tag => "#{s.version}" }

  s.ios.deployment_target = "15.0"

  s.source_files = "HaishinKit/Sources/**/*.swift"
  s.dependency 'Logboard', '~> 2.3.1'
end