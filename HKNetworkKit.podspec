# The pod `name` must be globally unique on CocoaPods trunk. "HKNetworkKit" is
# a personal-prefix name and should be available; if `pod trunk push` reports a
# clash, pick another unique name. Set the homepage/source URLs to your repo.

Pod::Spec.new do |s|
  s.name             = 'HKNetworkKit'
  s.version          = '1.0.0'
  s.summary          = 'A modern, dependency-free Swift networking toolkit (async/await), plus optional image loading and keyboard handling.'
  s.description      = <<-DESC
    HKNetworkKit is a production-ready, URLSession-based networking framework built
    on async/await, with retries, interceptors, auth, SSL pinning and reachability.
    Optional modules add SDWebImage-style image loading and IQKeyboardManager-style
    keyboard handling — all with zero third-party dependencies.
  DESC
  s.homepage         = 'https://github.com/harsh-171095/HKNetworkKit'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Harsh Kadiya' => 'harshraj.gohil171095@gmail.com' }
  s.source           = { :git => 'https://github.com/harsh-171095/HKNetworkKit.git', :tag => s.version.to_s }

  s.swift_versions = ['6.0']
  s.ios.deployment_target    = '15.0'
  s.osx.deployment_target    = '12.0'
  s.tvos.deployment_target   = '15.0'
  s.watchos.deployment_target = '8.0'

  s.default_subspec = 'Core'

  # Core networking — cross-platform, no dependencies.
  s.subspec 'Core' do |core|
    core.source_files = 'Sources/HKNetworkKit/**/*.swift'
    core.frameworks   = 'Foundation', 'Security', 'CryptoKit', 'Network'
  end

  # Image loading (UIKit + SwiftUI helpers).
  s.subspec 'Image' do |image|
    image.dependency 'HKNetworkKit/Core'
    image.source_files = 'Sources/HKNetworkKitImage/**/*.swift'
    image.frameworks   = 'CryptoKit'
    image.ios.frameworks    = 'UIKit'
    image.tvos.frameworks   = 'UIKit'
    image.osx.frameworks    = 'AppKit'
  end

  # Automatic keyboard handling (iOS only; code is guarded with #if os(iOS)).
  s.subspec 'Keyboard' do |keyboard|
    keyboard.source_files     = 'Sources/KeyboardKit/**/*.swift'
    keyboard.ios.frameworks   = 'UIKit'
  end
end
