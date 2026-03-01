#!/bin/bash

# 自動將集成測試文件添加到 Xcode 項目
# 注意：這個腳本需要先安裝 xcodeproj gem

set -e

echo "🔧 將集成測試文件添加到 Xcode 項目..."
echo ""

PROJECT_DIR="/Users/wubaizong/havital/apps/ios/Havital"
cd "$PROJECT_DIR"

# 顏色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# 檢查是否安裝了 xcodeproj
if ! gem list xcodeproj -i > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  未安裝 xcodeproj gem${NC}"
    echo ""
    echo "請選擇以下方式之一："
    echo ""
    echo "方式 1: 使用 Xcode 手動添加（推薦）"
    echo "  1. 打開 Xcode: open Havital.xcodeproj"
    echo "  2. 右鍵 HavitalTests → Add Files to Havital..."
    echo "  3. 選擇 HavitalTests/Integration/ 下的所有文件"
    echo "  4. 確保勾選 'Add to targets: HavitalTests'"
    echo ""
    echo "方式 2: 安裝 xcodeproj gem 後重新運行此腳本"
    echo "  sudo gem install xcodeproj"
    echo ""
    exit 1
fi

echo -e "${BLUE}使用 Ruby 腳本添加文件...${NC}"
echo ""

# 使用 Ruby 腳本添加文件
ruby << 'RUBY_SCRIPT'
require 'xcodeproj'

project_path = 'Havital.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# 找到 HavitalTests target
test_target = project.targets.find { |t| t.name == 'HavitalTests' }

unless test_target
  puts "❌ 找不到 HavitalTests target"
  exit 1
end

# 找到 HavitalTests 組
test_group = project.main_group.find_subpath('HavitalTests', true)

unless test_group
  puts "❌ 找不到 HavitalTests 組"
  exit 1
end

# 創建或找到 Integration 組
integration_group = test_group.find_subpath('Integration', true) || test_group.new_group('Integration')

# 要添加的文件
files_to_add = [
  'HavitalTests/Integration/IntegrationTestBase.swift',
  'HavitalTests/Integration/Repositories/TrainingPlanRepositoryIntegrationTests.swift',
  'HavitalTests/Integration/UseCases/TrainingPlanUseCaseIntegrationTests.swift',
  'HavitalTests/Integration/EndToEnd/TrainingPlanFlowIntegrationTests.swift'
]

added_count = 0

files_to_add.each do |file_path|
  if File.exist?(file_path)
    # 檢查文件是否已經在項目中
    existing_file = project.files.find { |f| f.path == file_path }

    unless existing_file
      # 添加文件引用
      file_ref = integration_group.new_file(file_path)

      # 添加到 build phase
      test_target.source_build_phase.add_file_reference(file_ref)

      puts "✅ 已添加: #{file_path}"
      added_count += 1
    else
      puts "ℹ️  已存在: #{file_path}"
    end
  else
    puts "⚠️  文件不存在: #{file_path}"
  end
end

if added_count > 0
  project.save
  puts ""
  puts "✅ 成功添加 #{added_count} 個文件到項目"
else
  puts ""
  puts "ℹ️  所有文件已存在於項目中"
end
RUBY_SCRIPT

echo ""
echo -e "${GREEN}✅ 完成！${NC}"
echo ""
echo "下一步："
echo "  運行集成測試: ./Scripts/run_integration_tests.sh"
