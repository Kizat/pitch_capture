#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint pitch_capture.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'pitch_capture'
  s.version          = '1.0.0'
  s.summary          = 'audio stream capture for iOS and Android OS'
  s.description      = <<-DESC
                        audio stream capture for iOS and Android OS.
                       DESC
  s.homepage         = 'https://github.com/'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Kizat Dauletuly' => 'kishon2810@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '13.6'

  # Flutter.framework does not contain a i386 slice. Only x86_64 simulators are supported.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'VALID_ARCHS[sdk=iphonesimulator*]' => 'x86_64' }
  s.swift_version = '5.0'
end
