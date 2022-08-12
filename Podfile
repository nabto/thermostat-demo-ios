platform :ios, '12.0'

  post_install do |installer|
    installer.pods_project.targets.each do |target|
      target.build_configurations.each do |config|
        config.build_settings['BUILD_LIBRARY_FOR_DISTRIBUTION'] = 'YES'
      end
    end
  end

def common
  use_frameworks!
  pod 'NabtoEdgeClientSwift'
  pod 'NabtoEdgeIamUtil'
  pod 'NotificationBannerSwift', '~> 3.0.0'
end

target 'Edge Heat' do
  common
end

target 'HeatpumpDemoTests' do
  common
end
