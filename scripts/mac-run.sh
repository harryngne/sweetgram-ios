#!/bin/bash
# Dùng trên máy Mac có Xcode: tạo dự án rồi mở Xcode để cài thẳng vào iPhone (cắm cáp).
#   bash scripts/mac-run.sh            (tài khoản Apple Developer trả phí: có thông báo đẩy)
#   SWEETGRAM_PUSH=0 bash scripts/mac-run.sh   (Apple ID miễn phí: không có thông báo đẩy, cài lại mỗi 7 ngày)
set -e
export SWEETGRAM_APS=${SWEETGRAM_APS:-development}   # chạy từ Xcode = môi trường thử của Apple
cd "$(dirname "$0")/.."
command -v npm >/dev/null || { echo "Cần cài Node.js (https://nodejs.org)"; exit 1; }
gem list -i xcodeproj >/dev/null || sudo gem install xcodeproj --no-document
npm install
node scripts/prepare.mjs
[ -d ios ] || npx cap add ios
npx cap sync ios
ruby scripts/setup-ios.rb
open ios/App/App.xcodeproj
echo "→ Trong Xcode: chọn target App và SweetWidget → Signing & Capabilities → Team = Apple ID của bạn; cắm iPhone → bấm ▶︎"
