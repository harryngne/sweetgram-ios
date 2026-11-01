#!/bin/bash
# Chọn Xcode mới nhất có trên máy Mac của GitHub Actions
X=$(ls -d /Applications/Xcode_*.app 2>/dev/null | grep -v beta | sort -V | tail -1)
[ -n "$X" ] && sudo xcode-select -s "$X/Contents/Developer"
xcodebuild -version
