require 'xcodeproj'
require 'fileutils'

project_path = 'ios/Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target_name = 'OmniLightWidget'

# Check if target already exists
if project.targets.any? { |t| t.name == target_name }
  puts "Target #{target_name} already exists."
  exit
end

puts "Creating target #{target_name}..."

# Create new app extension target
widget_target = project.new_target(:app_extension, target_name, :ios, '14.0')
widget_target.product_name = target_name
widget_target.product_type = 'com.apple.product-type.app-extension'

# Add files to group
widget_group = project.main_group.find_subpath(target_name, true)
widget_group.set_source_tree('<group>')
widget_group.path = target_name

file1 = widget_group.new_file('OmniLightWidget.swift')
file2 = widget_group.new_file('OmniLightWidgetBundle.swift')

# Add sources to build phase
widget_target.source_build_phase.add_file_reference(file1)
widget_target.source_build_phase.add_file_reference(file2)

# Create Info.plist for the widget
plist_path = "ios/#{target_name}/Info.plist"
unless File.exist?(plist_path)
  File.write(plist_path, <<~XML)
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>CFBundleIdentifier</key>
      <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
      <key>CFBundleName</key>
      <string>$(PRODUCT_NAME)</string>
      <key>CFBundleDisplayName</key>
      <string>OmniLight Widget</string>
      <key>CFBundleShortVersionString</key>
      <string>1.0</string>
      <key>CFBundleVersion</key>
      <string>1</string>
      <key>CFBundlePackageType</key>
      <string>XPC!</string>
      <key>NSExtension</key>
      <dict>
        <key>NSExtensionPointIdentifier</key>
        <string>com.apple.widgetkit-extension</string>
      </dict>
    </dict>
    </plist>
  XML
end

plist_ref = widget_group.new_file('Info.plist')

# Configure build settings for the widget
widget_target.build_configurations.each do |config|
  config.build_settings['INFOPLIST_FILE'] = "#{target_name}/Info.plist"
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = "com.abstrackt.omnilight.#{target_name}"
  config.build_settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = "AppIcon"
  config.build_settings['ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME'] = "AccentColor"
  config.build_settings['ASSETCATALOG_COMPILER_WIDGET_BACKGROUND_COLOR_NAME'] = "WidgetBackground"
  config.build_settings['TARGETED_DEVICE_FAMILY'] = "1,2" # iPhone & iPad
  config.build_settings['SWIFT_VERSION'] = "5.0"
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = "14.0"
  config.build_settings['PRODUCT_NAME'] = "$(TARGET_NAME)"
end

# Make Runner depend on OmniLightWidget
main_target = project.targets.find { |t| t.name == 'Runner' }
main_target.add_dependency(widget_target)

# Embed App Extension into Runner
embed_phase = main_target.new_copy_files_build_phase('Embed App Extensions')
embed_phase.dst_subfolder_spec = '13' # Plugins
embed_phase.add_file_reference(widget_target.product_reference, true) # Code sign on copy

# Fix Dependency Cycle: Move Embed phase before any Script phases (e.g. Thin Binary)
main_target.build_phases.delete(embed_phase)
first_script_index = main_target.build_phases.index { |p| p.isa == 'PBXShellScriptBuildPhase' }
if first_script_index
  main_target.build_phases.insert(first_script_index, embed_phase)
else
  main_target.build_phases << embed_phase
end

# Workaround for Frameworks (since it's a widget, SwiftUI and WidgetKit are needed)
frameworks_phase = widget_target.frameworks_build_phase
frameworks_phase.add_file_reference(project.frameworks_group.new_file('WidgetKit.framework'))
frameworks_phase.add_file_reference(project.frameworks_group.new_file('SwiftUI.framework'))

project.save
puts "Successfully configured Xcode project with Widget Extension."
