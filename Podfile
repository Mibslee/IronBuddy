# 必须使用 IronBuddy.xcworkspace 打开工程（勿单独打开 .xcodeproj），否则 MediaPipe 链接会失败：
# ld: framework 'MediaPipeTasksCommon' not found
# 命令行：xcodebuild -workspace IronBuddy.xcworkspace -scheme IronBuddy ...

platform :ios, '17.0'

target 'IronBuddy' do
  use_frameworks!
  # 0.10.33+ 在部分 Xcode 下 -lMediaPipeTasksCommon 链接失败；0.10.21 为社区验证可用版本。
  pod 'MediaPipeTasksVision', '0.10.21'
end

target 'IronBuddyTests' do
  inherit! :search_paths
end

target 'IronBuddyUITests' do
  inherit! :search_paths
end
