#!/bin/bash

# ==============================================================================
# Cache Transfer Script V2: Emulator -> Physical Device (Internal Storage)
# App: com.example.agroww_sih
# Target: /data/data/com.example.agroww_sih/app_flutter/timeseries_cache
# ==============================================================================

ADB_PATH="/Users/aniketmandal06/Library/Android/sdk/platform-tools/adb"
PACKAGE_NAME="com.example.agroww_sih"
# We specifically want the FLUTTER internal documents directory
INTERNAL_PATH="app_flutter/timeseries_cache"
FULL_INTERNAL_PATH="/data/data/$PACKAGE_NAME/$INTERNAL_PATH"
TEMP_DIR="./emulator_cache_backup"
ZIP_FILE="timeseries_cache_backup.zip"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

echo -e "${GREEN}=== Android Cache Transfer Tool V2 ===${NC}"
echo -e "${YELLOW}Targeting Internal Cache: $INTERNAL_PATH${NC}"

# 1. Device Selection
"$ADB_PATH" devices
echo -e "\n--------------------------------------------------"
echo "Enter EMULATOR ID (default: emulator-5554):"
read -r EMULATOR_ID
EMULATOR_ID=${EMULATOR_ID:-emulator-5554}

echo "Enter PHYSICAL DEVICE ID (Optional - Press Enter to skip):"
read -r DEVICE_ID

# 2. PULL from Emulator
echo -e "\n${GREEN}Step 1: Pulling from Emulator ($EMULATOR_ID)...${NC}"
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"

# Try exec-out + tar (Best for non-rooted)
echo "Streaming data via tar..."
"$ADB_PATH" -s "$EMULATOR_ID" exec-out "run-as $PACKAGE_NAME tar c $INTERNAL_PATH" > "$TEMP_DIR/cache.tar"

if [ -s "$TEMP_DIR/cache.tar" ]; then
    echo "Extracting..."
    cd "$TEMP_DIR" || exit
    tar -xf cache.tar
    rm cache.tar
    cd - > /dev/null
    echo -e "${GREEN}Success: Pulled to $TEMP_DIR/$INTERNAL_PATH${NC}"
else
    echo -e "${RED}Failed to pull via tar. Trying root method...${NC}"
    "$ADB_PATH" -s "$EMULATOR_ID" root
    "$ADB_PATH" -s "$EMULATOR_ID" pull "$FULL_INTERNAL_PATH" "$TEMP_DIR/timeseries_cache"
    
    if [ $? -eq 0 ]; then
        # Re-structure for consistency
        mkdir -p "$TEMP_DIR/app_flutter"
        mv "$TEMP_DIR/timeseries_cache" "$TEMP_DIR/app_flutter/"
        echo -e "${GREEN}Success (Root): Pulled to $TEMP_DIR/$INTERNAL_PATH${NC}"
    else
        echo -e "${RED}CRITICAL: Could not pull cache. Is the app installed and debuggable?${NC}"
        exit 1
    fi
fi

# Zip it
echo "Creating backup zip..."
zip -r "$ZIP_FILE" "$TEMP_DIR" > /dev/null
echo -e "${GREEN}Backup created: $ZIP_FILE${NC}"

# 3. PUSH to Physical Device
if [ -z "$DEVICE_ID" ]; then
    echo -e "${YELLOW}Skipping push to device.${NC}"
    exit 0
fi

echo -e "\n${GREEN}Step 2: Pushing to Physical Device ($DEVICE_ID)...${NC}"
echo -e "${YELLOW}NOTE: This requires the app on your phone to be a DEBUG build (run from Android Studio).${NC}"

# Push to /data/local/tmp first (writable)
echo "Pushing to temporary location..."
# We need to push the CONTENTS of timeseries_cache into a temp folder
# Local: ./emulator_cache_backup/app_flutter/timeseries_cache
# Remote: /data/local/tmp/timeseries_cache_transfer

LOCAL_CACHE_PATH="$TEMP_DIR/$INTERNAL_PATH"
REMOTE_TMP_PATH="/data/local/tmp/timeseries_cache_transfer"

# Clean remote temp
"$ADB_PATH" -s "$DEVICE_ID" shell "rm -rf $REMOTE_TMP_PATH"
"$ADB_PATH" -s "$DEVICE_ID" push "$LOCAL_CACHE_PATH" "$REMOTE_TMP_PATH"

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to push files to device temp storage.${NC}"
    exit 1
fi

echo "Moving to internal storage via run-as..."
# The tricky part: cp -r inside run-as
# We need to make sure the target directory exists
"$ADB_PATH" -s "$DEVICE_ID" shell "run-as $PACKAGE_NAME mkdir -p $INTERNAL_PATH"

# Copy files
"$ADB_PATH" -s "$DEVICE_ID" shell "run-as $PACKAGE_NAME cp -r $REMOTE_TMP_PATH/* $INTERNAL_PATH/"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}SUCCESS! Cache injected into app internal storage.${NC}"
    echo "Restart your app now."
    # Cleanup
    "$ADB_PATH" -s "$DEVICE_ID" shell "rm -rf $REMOTE_TMP_PATH"
else
    echo -e "${RED}Failed to move files internally.${NC}"
    echo "This usually means your app on the phone is a RELEASE build."
    echo "Please uninstall it and run 'flutter run --debug' or install a debug APK."
fi
