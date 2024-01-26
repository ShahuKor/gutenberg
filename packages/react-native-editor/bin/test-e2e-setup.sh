#!/bin/bash -e

set -o pipefail

if command -v appium >/dev/null 2>&1; then
	APPIUM_CMD="appium"
else
	# Use relative path to access the locally installed appium
	APPIUM_CMD="../../../node_modules/.bin/appium"
fi

function log_info() {
	printf "ℹ️  $1\n"
}

function log_success {
	printf "✅ $1\n"
}

function log_error() {
	printf "❌ $1\n"
}

TEST_ENV=${TEST_ENV:-"local"}
output=$($APPIUM_CMD driver list --installed --json)

if echo "$output" | grep -q 'uiautomator2'; then
	log_info "UiAutomator2 available."
else
	log_info "UiAutomator2 not found, installing..."
	$APPIUM_CMD driver install uiautomator2
fi

if echo "$output" | grep -q 'xcuitest'; then
	log_info "XCUITest available."
else
	log_info "XCUITest not found, installing..."
	$APPIUM_CMD driver install xcuitest
fi

CONFIG_FILE="$(pwd)/__device-tests__/helpers/device-config.json"
IOS_PLATFORM_VERSION=$(jq -r ".ios.$TEST_ENV.platformVersion" "$CONFIG_FILE")

# Throw an error if the required iOS runtime is not installed
IOS_RUNTIME_INSTALLED=$(xcrun simctl list runtimes -j | jq -r --arg version "$IOS_PLATFORM_VERSION" '.runtimes | to_entries[] | select(.value.version | contains($version))')
if [[ -z $IOS_RUNTIME_INSTALLED ]]; then
	log_error "iOS $IOS_PLATFORM_VERSION runtime not found! Please install the iOS $IOS_PLATFORM_VERSION runtime using Xcode.\n    https://developer.apple.com/documentation/xcode/installing-additional-simulator-runtimes#Install-and-manage-Simulator-runtimes-in-settings"
	exit 1;
fi

function detect_or_create_simulator() {
	local simulator_name=$1
	local runtime_name_display=$(echo "iOS $IOS_PLATFORM_VERSION")
	local runtime_name=$(echo "$runtime_name_display" | sed 's/ /-/g; s/\./-/g')
	local simulators=$(xcrun simctl list devices -j | jq -r --arg runtime "$runtime_name" '.devices | to_entries[] | select(.key | contains($runtime)) | .value[] | .name + "," + .udid')

	if ! echo "$simulators" | grep -q "$simulator_name"; then
		log_info "$simulator_name ($runtime_name_display) not found, creating..."
		xcrun simctl create "$simulator_name" "$simulator_name" "com.apple.CoreSimulator.SimRuntime.$runtime_name" > /dev/null
		log_success "$simulator_name ($runtime_name_display) created."
	else
		log_info "$simulator_name ($runtime_name_display) available."
	fi
}

IOS_DEVICE_NAME=$(jq -r ".ios.$TEST_ENV.deviceName" "$CONFIG_FILE")
IOS_DEVICE_TABLET_NAME=$(jq -r ".ios.$TEST_ENV.deviceTabletName" "$CONFIG_FILE")

# Create the required iOS simulators, if they don't exist
detect_or_create_simulator "$IOS_DEVICE_NAME"
detect_or_create_simulator "$IOS_DEVICE_TABLET_NAME"

function detect_or_create_emulator() {
	if [[ "${CI}" ]]; then
		log_info "Detected CI server, skipping Android emulator creation."
		return
	fi

	if [[ -z $(command -v avdmanager) ]]; then
		log_error "avdmanager not found! Please install the Android SDK command-line tools.\n    https://developer.android.com/tools/"
		exit 1;
	fi

	local emulator_name=$1
	local emulator_id=$(echo "$emulator_name" | sed 's/ /_/g; s/\./_/g')
	local device_id=$(echo "$emulator_id" | awk -F '_' '{print tolower($1)"_"tolower($2)"_"tolower($3)}')
	local runtime_api=$(echo "$emulator_id" | awk -F '_' '{print $NF}')
	local emulator=$(emulator -list-avds | grep "$emulator_id")

	if [[ -z $emulator ]]; then
		log_info "$emulator_name not found, creating..."
		avdmanager create avd -n "$emulator_id" -k "system-images;android-$runtime_api;google_apis;arm64-v8a" -d "$device_id" > /dev/null
		log_success "$emulator_name created."
	else
		log_info "$emulator_name available."
	fi
}

ANDROID_DEVICE_NAME=$(jq -r '.android.local.deviceName' "$CONFIG_FILE")

# Create the required Android emulators, if they don't exist
detect_or_create_emulator $ANDROID_DEVICE_NAME

# Mitigate conflicts between development server caches and E2E tests
npm run clean:runtime > /dev/null
log_info 'Runtime cache cleared.'
