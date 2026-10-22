#!/bin/sh
# Single source of truth for the simulator test target. Docs and other tooling
# point here instead of embedding their own copy of the destination string —
# several drifting copies of the same OS/device pair is how a real-device
# deployment target accidentally gets bumped to match a test simulator's OS.
#
# This is the TEST target only. It has no bearing on project.yml's
# deploymentTarget (the real minimum OS the shipped app supports) — update
# that separately and deliberately, never by copying this value.
set -e
cd "$(dirname "$0")/.."
xcodegen generate
xcodebuild test -project Tuck.xcodeproj -scheme Tuck \
  -destination 'platform=iOS Simulator,OS=26.5,name=iPhone 17'
