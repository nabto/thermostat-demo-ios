platform :ios, '12.0'

target 'Edge Heat' do
  use_frameworks!
  pod 'NabtoClient'
  pod 'NabtoEdgeClientSwift'
  pod 'NabtoEdgeIamUtil'

  post_install do |installer|
    installer.pods_project.targets.each do |target|
      target.build_configurations.each do |config|
        config.build_settings['BUILD_LIBRARY_FOR_DISTRIBUTION'] = 'YES'
      end
    end
  end
end

target 'HeatpumpDemoTests' do
  pod 'NabtoClient'
end
