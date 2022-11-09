# Uncomment the next line to define a global platform for your project
platform :ios, '11.0'

# ignore all warnings from all pods
inhibit_all_warnings!

target 'AptoSDK iOS' do
  # Comment the next line if you're not using Swift and don't want to use dynamic frameworks
  use_frameworks!

  # Pods for AptoSDK iOS
  pod 'Alamofire', '~> 5.4.3'
  pod 'Bond', '~> 7.6'
  pod 'SwiftyJSON', '~> 5.0'
  pod 'GoogleKit', '~> 0.3'
  pod 'PhoneNumberKit', '~> 3.3.3'
  pod 'TrustKit', '~> 1.6'
  pod 'FTLinearActivityIndicator', '1.2.1'
  pod 'AlamofireNetworkActivityIndicator', '~> 3.1'
  pod 'Mixpanel-swift', '~> 3.2.0'
  
end


post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['CLANG_WARN_DOCUMENTATION_COMMENTS'] = 'NO'
      config.build_settings['ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES'] = 'YES'
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '11.0'
    end
  end
end
