#!/usr/bin/env ruby
# Script to add MLX Swift Examples package to Xcode project

require 'fileutils'

project_file = "NotedCore.xcodeproj/project.pbxproj"

unless File.exist?(project_file)
  puts "❌ Error: #{project_file} not found"
  exit 1
end

puts "🔧 Adding MLX Swift Examples package to Xcode project..."

# Read the project file
content = File.read(project_file)

# Generate new UUIDs for the package references
mlx_examples_ref_uuid = "D0FE6AEC#{rand(100000000).to_s.upcase.ljust(8, '0')[0..7]}0019CD1F"
mlxllm_uuid = "D0FE6AED#{rand(100000000).to_s.upcase.ljust(8, '0')[0..7]}0019CD1F"
mlxlmcommon_uuid = "D0FE6AEE#{rand(100000000).to_s.upcase.ljust(8, '0')[0..7]}0019CD1F"

# Add the new package reference
package_ref = "\t\t#{mlx_examples_ref_uuid} /* XCRemoteSwiftPackageReference \"mlx-swift-examples\" */ = {
\t\t\tisa = XCRemoteSwiftPackageReference;
\t\t\trepositoryURL = \"https://github.com/ml-explore/mlx-swift-examples\";
\t\t\trequirement = {
\t\t\t\tbranch = main;
\t\t\t\tkind = branch;
\t\t\t};
\t\t};"

# Add after the existing MLX package
content.gsub!(/(\t\tD0FE6AE12E1F6F0B0019CD1F \/\* XCRemoteSwiftPackageReference "mlx-swift" \*\/ = \{[^}]+\};\n)/) do |match|
  "#{match}\n#{package_ref}\n"
end

# Add product dependencies
mlxllm_product = "\t\t#{mlxllm_uuid} /* MLXLLM */ = {
\t\t\tisa = XCSwiftPackageProductDependency;
\t\t\tpackage = #{mlx_examples_ref_uuid} /* XCRemoteSwiftPackageReference \"mlx-swift-examples\" */;
\t\t\tproductName = MLXLLM;
\t\t};"

mlxlmcommon_product = "\t\t#{mlxlmcommon_uuid} /* MLXLMCommon */ = {
\t\t\tisa = XCSwiftPackageProductDependency;
\t\t\tpackage = #{mlx_examples_ref_uuid} /* XCRemoteSwiftPackageReference \"mlx-swift-examples\" */;
\t\t\tproductName = MLXLMCommon;
\t\t};"

# Add after the last MLX product dependency
content.gsub!(/(\t\tD0FE6AEA2E1F6F0B0019CD1F \/\* MLXNN \*\/ = \{[^}]+\};\n)/) do |match|
  "#{match}#{mlxllm_product}\n#{mlxlmcommon_product}\n"
end

# Add to the main target's packageProductDependencies
content.gsub!(/(packageProductDependencies = \(\n\t\t\t\tD0FE6AD92E1F3F1F0019CD1F \/\* WhisperKit \*\/,\n\t\t\t\tD0FE6ADB2E1F3F1F0019CD1F \/\* whisperkit-cli \*\/,\n\t\t\t\tD0FE6AE22E1F6F0B0019CD1F \/\* MLX \*\/,\n\t\t\t\tD0FE6AE42E1F6F0B0019CD1F \/\* MLXFFT \*\/,\n\t\t\t\tD0FE6AE62E1F6F0B0019CD1F \/\* MLXFast \*\/,\n\t\t\t\tD0FE6AE82E1F6F0B0019CD1F \/\* MLXLinalg \*\/,\n\t\t\t\tD0FE6AEA2E1F6F0B0019CD1F \/\* MLXNN \*\/,)/) do |match|
  "#{match}\n\t\t\t\t#{mlxllm_uuid} /* MLXLLM */,\n\t\t\t\t#{mlxlmcommon_uuid} /* MLXLMCommon */,"
end

# Add to package references list
content.gsub!(/(packageReferences = \(\n\t\t\t\tD0FE6AD82E1F3F1F0019CD1F \/\* XCRemoteSwiftPackageReference "WhisperKit" \*\/,\n\t\t\t\tD0FE6AE12E1F6F0B0019CD1F \/\* XCRemoteSwiftPackageReference "mlx-swift" \*\/,)/) do |match|
  "#{match}\n\t\t\t\t#{mlx_examples_ref_uuid} /* XCRemoteSwiftPackageReference \"mlx-swift-examples\" */,"
end

# Write the updated content
File.write(project_file, content)

puts "✅ Successfully added MLX Swift Examples package to Xcode project!"
puts "📦 Added packages:"
puts "   - MLXLLM"
puts "   - MLXLMCommon"
puts ""
puts "🚀 Next steps:"
puts "   1. Clean build folder: Shift+Cmd+K in Xcode"
puts "   2. Build project: Cmd+B"
puts "   3. Run app and test AI generation!"
puts ""
puts "⚠️  Note: First run will download ~2GB Phi-3 model (requires internet)"