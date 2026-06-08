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

# Read pubspec.yaml to get the version
pubspec_content = File.read('pubspec.yaml')
version_line = pubspec_content.lines.find { |l| l.start_with?('version:') }
# version: 1.0.0+1 -> name: 1.0.0, number: 1
version_str = version_line.split(':')[1].strip
version_name = version_str.split('+')[0]
version_number = version_str.split('+')[1] || '1'

# Create Info.plist for the widget
plist_path = "ios/#{target_name}/Info.plist"
unless File.exist?(plist_path)
  File.write(plist_path, <<~XML)
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>CFBundleDevelopmentRegion</key>
      <string>$(DEVELOPMENT_LANGUAGE)</string>
      <key>CFBundleInfoDictionaryVersion</key>
      <string>6.0</string>
      <key>CFBundleIdentifier</key>
      <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
      <key>CFBundleName</key>
      <string>$(PRODUCT_NAME)</string>
      <key>CFBundleExecutable</key>
      <string>$(EXECUTABLE_NAME)</string>
      <key>CFBundleDisplayName</key>
      <string>OmniLight Widget</string>
      <key>CFBundleShortVersionString</key>
      <string>#{version_name}</string>
      <key>CFBundleVersion</key>
      <string>#{version_number}</string>
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

# Create minimal Assets.xcassets for the widget
assets_path = "ios/#{target_name}/Assets.xcassets"
unless Dir.exist?(assets_path)
  FileUtils.mkdir_p("#{assets_path}/AppIcon.appiconset")
  File.write("#{assets_path}/AppIcon.appiconset/Contents.json", <<~JSON)
    {
      "images" : [ ],
      "info" : { "author" : "xcode", "version" : 1 }
    }
  JSON
end

plist_ref = widget_group.new_file('Info.plist')
assets_ref = widget_group.new_file('Assets.xcassets')

# Configure build settings for the widget
widget_target.build_configurations.each do |config|
  config.build_settings['INFOPLIST_FILE'] = "#{target_name}/Info.plist"
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = "com.abstrackt.omnilight.#{target_name}"
  config.build_settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = "AppIcon"
  config.build_settings['TARGETED_DEVICE_FAMILY'] = "1,2" # iPhone & iPad
  config.build_settings['SKIP_INSTALL'] = "YES"
  config.build_settings['SWIFT_VERSION'] = "5.0"
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = "14.0"
  config.build_settings['PRODUCT_NAME'] = target_name
  
  generated_xcconfig = project.files.find { |f| f.path && f.path.include?('Generated.xcconfig') }
  config.base_configuration_reference = generated_xcconfig if generated_xcconfig
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

# Add resources (Assets.xcassets) to build phase
resources_phase = widget_target.resources_build_phase
resources_phase.add_file_reference(assets_ref)

project.save
puts "Successfully configured Xcode project with Widget Extension."
