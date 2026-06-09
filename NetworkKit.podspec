# ⚠️  The pod `name` must be GLOBALLY UNIQUE on CocoaPods trunk.
#     "NetworkKit" is almost certainly taken — rename this (and the file) to
#     something unique, e.g. "NuverseNetworkKit", before `pod trunk push`.
#     SwiftPM users are unaffected; this only matters for CocoaPods.

Pod::Spec.new do |s|
  s.name             = 'NetworkKit'
  s.version          = '1.0.0'
  s.summary          = 'A modern, dependency-free Swift networking toolkit (async/await), plus optional image loading and keyboard handling.'
  s.description      = <<-DESC
    NetworkKit is a production-ready, URLSession-based networking framework built
    on async/await, with retries, interceptors, auth, SSL pinning and reachability.
    Optional modules add SDWebImage-style image loading and IQKeyboardManager-style
    keyboard handling — all with zero third-party dependencies.
  DESC
  s.homepage         = 'https://github.com/<your-username>/NetworkKit'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Harsh Kadiya' => 'support@nuverse.in' }
  s.source           = { :git => 'https://github.com/<your-username>/NetworkKit.git', :tag => s.version.to_s }

  s.swift_versions = ['6.0']
  s.ios.deployment_target    = '15.0'
  s.osx.deployment_target    = '12.0'
  s.tvos.deployment_target   = '15.0'
  s.watchos.deployment_target = '8.0'

  s.default_subspec = 'Core'

  # Core networking — cross-platform, no dependencies.
  s.subspec 'Core' do |core|
    core.source_files = 'Sources/NetworkKit/**/*.swift'
    core.frameworks   = 'Foundation', 'Security', 'CryptoKit', 'Network'
  end

  # Image loading (UIKit + SwiftUI helpers).
  s.subspec 'Image' do |image|
    image.dependency 'NetworkKit/Core'
    image.source_files = 'Sources/NetworkKitImage/**/*.swift'
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
