# encoding: utf-8
Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8
# Bổ sung cho dự án Xcode do Capacitor tạo: plugin widget, widget màn hình chính, App Group, thông báo, icon, quyền camera/micro.
# Chạy lại bao nhiêu lần cũng được (không thêm trùng). Cần: gem install xcodeproj
require 'xcodeproj'
require 'json'
require 'fileutils'

ROOT = File.expand_path('..', __dir__)
CFG  = JSON.parse(File.read(File.join(ROOT, 'scripts/.resolved.json')))
APP_ID = CFG['appId']; TEAM = CFG['team'].to_s; GROUP = "group.#{APP_ID}"
WIDGET_ID = "#{APP_ID}.widget"
SHARE_ID = "#{APP_ID}.share"
PUSH = ENV.fetch('SWEETGRAM_PUSH', '1') != '0'      # tài khoản Apple ID miễn phí: đặt SWEETGRAM_PUSH=0
IOS = File.join(ROOT, 'ios/App')
puts "▶ Cấu hình Xcode: #{APP_ID} · nhóm #{GROUP} · team #{TEAM.empty? ? '(chưa đặt — chọn trong Xcode)' : TEAM} · thông báo #{PUSH ? 'bật' : 'tắt'}"

# ---------- chép mã nguồn ----------
FileUtils.cp(Dir[File.join(ROOT, 'native/App/*.swift')], File.join(IOS, 'App'))
FileUtils.mkdir_p(File.join(IOS, 'SweetWidget'))
FileUtils.cp(Dir[File.join(ROOT, 'native/SweetWidget/*')], File.join(IOS, 'SweetWidget'))
FileUtils.mkdir_p(File.join(IOS, 'Shared')); FileUtils.cp(Dir[File.join(ROOT, 'native/Shared/*.swift')], File.join(IOS, 'Shared'))
FileUtils.mkdir_p(File.join(IOS, 'ShareExt')); FileUtils.cp(Dir[File.join(ROOT, 'native/ShareExt/*')], File.join(IOS, 'ShareExt'))
FileUtils.cp(File.join(ROOT, 'native/AppIcon-1024.png'), File.join(IOS, 'App/Assets.xcassets/AppIcon.appiconset/AppIcon-512@2x.png'))

# ---------- AppDelegate: chuyển mã thiết bị cho plugin thông báo ----------
ad = File.join(IOS, 'App/AppDelegate.swift'); s = File.read(ad)
unless s.include?('capacitorDidRegisterForRemoteNotifications')
  s = s.sub(/\}\s*\z/, <<~SW)

      func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
          NotificationCenter.default.post(name: .capacitorDidRegisterForRemoteNotifications, object: deviceToken)
      }

      func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
          NotificationCenter.default.post(name: .capacitorDidFailToRegisterForRemoteNotifications, object: error)
      }
  }
  SW
  File.write(ad, s)
end

# ---------- màn hình chính dùng MainViewController (để đăng ký plugin widget) ----------
sb = File.join(IOS, 'App/Base.lproj/Main.storyboard'); s = File.read(sb)
File.write(sb, s.gsub('customClass="CAPBridgeViewController" customModule="Capacitor"', 'customClass="MainViewController" customModule="App" customModuleProvider="target"'))

# ---------- Info.plist của app ----------
pl = File.join(IOS, 'App/Info.plist'); info = Xcodeproj::Plist.read_from_path(pl)
info['CFBundleDevelopmentRegion'] = 'vi'
info['SweetgramAppGroup'] = GROUP
info['SweetgramApsEnv'] = ENV.fetch('SWEETGRAM_APS', 'production')
info['NSCameraUsageDescription'] = 'Sweetgram dùng camera để chụp ảnh, quay video, gọi video và phát trực tiếp.'
info['NSMicrophoneUsageDescription'] = 'Sweetgram dùng micro để ghi âm, gọi điện và phát trực tiếp.'
info['NSPhotoLibraryUsageDescription'] = 'Sweetgram cần quyền ảnh để bạn chọn ảnh/video gửi cho người ấy.'
info['NSPhotoLibraryAddUsageDescription'] = 'Sweetgram lưu ảnh/video vào thư viện khi bạn bấm Lưu.'
info['NSLocationWhenInUseUsageDescription'] = 'Sweetgram dùng vị trí khi bạn chia sẻ vị trí hoặc gắn địa điểm cho ảnh.'
info['UIBackgroundModes'] = PUSH ? ['remote-notification', 'audio'] : ['audio']
info['CFBundleURLTypes'] = [{ 'CFBundleURLName' => APP_ID, 'CFBundleURLSchemes' => ['sweetgram'] }]
info['ITSAppUsesNonExemptEncryption'] = false
info['NSSupportsLiveActivities'] = true                 # 11.5: Live Activity (màn hình khoá + Dynamic Island)
info['NSSupportsLiveActivitiesFrequentUpdates'] = true
Xcodeproj::Plist.write_to_path(info, pl)
wp = File.join(IOS, 'SweetWidget/Info.plist'); wi = Xcodeproj::Plist.read_from_path(wp)
wi['SweetgramAppGroup'] = GROUP; Xcodeproj::Plist.write_to_path(wi, wp)
sp = File.join(IOS, 'ShareExt/Info.plist'); si = Xcodeproj::Plist.read_from_path(sp)
si['SweetgramAppGroup'] = GROUP; Xcodeproj::Plist.write_to_path(si, sp)

# ---------- quyền (entitlements) ----------
def ent(path, h) Xcodeproj::Plist.write_to_path(h, path) end
app_ent = { 'com.apple.security.application-groups' => [GROUP] }
app_ent['aps-environment'] = ENV.fetch('SWEETGRAM_APS', 'production') if PUSH
ent(File.join(IOS, 'App/App.entitlements'), app_ent)
ent(File.join(IOS, 'SweetWidget/SweetWidget.entitlements'), { 'com.apple.security.application-groups' => [GROUP] })
ent(File.join(IOS, 'ShareExt/ShareExt.entitlements'), { 'com.apple.security.application-groups' => [GROUP] })

# ---------- dự án Xcode ----------
proj = Xcodeproj::Project.open(File.join(IOS, 'App.xcodeproj'))
app = proj.targets.find { |t| t.name == 'App' } or abort 'Không thấy target App'
app_group = proj.main_group.find_subpath('App', false) or abort 'Không thấy nhóm App'
%w[MainViewController.swift WidgetBridgePlugin.swift LiveActivityPlugin.swift ScreenGuardPlugin.swift].each do |f|
  next if app_group.files.any? { |x| x.path == f }
  app.add_file_references([app_group.new_reference(f)])
end
app_group.new_reference('App.entitlements') unless app_group.files.any? { |x| x.path == 'App.entitlements' }

common = lambda do |t, bundle, entfile|
  t.build_configurations.each do |c|
    b = c.build_settings
    b['PRODUCT_BUNDLE_IDENTIFIER'] = bundle
    b['CODE_SIGN_ENTITLEMENTS'] = entfile
    b['CODE_SIGN_STYLE'] = 'Automatic'
    b['DEVELOPMENT_TEAM'] = TEAM unless TEAM.empty?
    b['MARKETING_VERSION'] = CFG['version']
    b['CURRENT_PROJECT_VERSION'] = CFG['build']
    b['SWEETGRAM_APP_GROUP'] = GROUP
    b['TARGETED_DEVICE_FAMILY'] = '1,2'
  end
end
common.call(app, APP_ID, 'App/App.entitlements')

widget = proj.targets.find { |t| t.name == 'SweetWidget' }
unless widget
  widget = proj.new_target(:app_extension, 'SweetWidget', :ios, '17.0', nil, :swift)
  wg = proj.main_group.new_group('SweetWidget', 'SweetWidget')
  widget.add_file_references([wg.new_reference('SweetWidget.swift')])
  wg.new_reference('Info.plist'); wg.new_reference('SweetWidget.entitlements')
  %w[WidgetKit SwiftUI].each { |f| widget.add_system_framework(f) }
  # nhúng widget vào app
  embed = app.new_copy_files_build_phase('Embed Foundation Extensions')
  embed.symbol_dst_subfolder_spec = :plug_ins
  bf = embed.add_file_reference(widget.product_reference, true)
  bf.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
  app.add_dependency(widget)
end
common.call(widget, WIDGET_ID, 'SweetWidget/SweetWidget.entitlements')

# ---------- 11.5: file dùng chung (Live Activity) cho App + widget; widget màn hình khoá ----------
shared = proj.main_group.find_subpath('Shared', false) || proj.main_group.new_group('Shared', 'Shared')
sref = shared.files.find { |x| x.path == 'SweetActivity.swift' } || shared.new_reference('SweetActivity.swift')
[app, widget].each { |t| t.add_file_references([sref]) unless t.source_build_phase.files_references.include?(sref) }
wg2 = proj.main_group.find_subpath('SweetWidget', false)
lref = wg2.files.find { |x| x.path == 'SweetLock.swift' } || wg2.new_reference('SweetLock.swift')
widget.add_file_references([lref]) unless widget.source_build_phase.files_references.include?(lref)
widget.add_system_framework('ActivityKit') unless widget.frameworks_build_phase.files_references.compact.any? { |f| f.path.to_s.include?('ActivityKit') }

# ---------- 11.5: Share Extension ("Chia sẻ" từ app Ảnh / Safari vào Sweetgram) ----------
share = proj.targets.find { |t| t.name == 'ShareExt' }
unless share
  share = proj.new_target(:app_extension, 'ShareExt', :ios, '16.0', nil, :swift)
  sg = proj.main_group.new_group('ShareExt', 'ShareExt')
  share.add_file_references([sg.new_reference('ShareViewController.swift')])
  sg.new_reference('Info.plist'); sg.new_reference('ShareExt.entitlements')
  %w[UIKit UniformTypeIdentifiers].each { |f| share.add_system_framework(f) }
  embed = app.copy_files_build_phases.find { |p| p.name == 'Embed Foundation Extensions' } || app.new_copy_files_build_phase('Embed Foundation Extensions')
  embed.symbol_dst_subfolder_spec = :plug_ins
  bf = embed.add_file_reference(share.product_reference, true)
  bf.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
  app.add_dependency(share)
end
common.call(share, SHARE_ID, 'ShareExt/ShareExt.entitlements')
share.build_configurations.each do |c|
  b = c.build_settings
  b['INFOPLIST_FILE'] = 'ShareExt/Info.plist'
  b['GENERATE_INFOPLIST_FILE'] = 'NO'
  b['IPHONEOS_DEPLOYMENT_TARGET'] = '16.0'
  b['SWIFT_VERSION'] = '5.0'
  b['SKIP_INSTALL'] = 'YES'
  b['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks']
end
widget.build_configurations.each do |c|
  b = c.build_settings
  b['INFOPLIST_FILE'] = 'SweetWidget/Info.plist'
  b['GENERATE_INFOPLIST_FILE'] = 'NO'
  b['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
  b['SWIFT_VERSION'] = '5.0'
  b['SKIP_INSTALL'] = 'YES'
  b['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks']
  b['ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME'] = ''
  b['ASSETCATALOG_COMPILER_WIDGET_BACKGROUND_COLOR_NAME'] = ''
end
# dấu "đã thử" cho cả hai target (xcodebuild -allowProvisioningUpdates cần TargetAttributes)
attrs = proj.root_object.attributes['TargetAttributes'] ||= {}
[app, widget, share].each { |t| (attrs[t.uuid] ||= {})['DevelopmentTeam'] = TEAM unless TEAM.empty? }
proj.save
puts '✅ Xong: target App + SweetWidget (màn hình chính, màn hình khoá, Live Activity) + ShareExt, App Group, thông báo, icon.'
