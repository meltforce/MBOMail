SCHEME = mboMail
PROJECT = mboMail.xcodeproj
BUILD_DIR = build
ARCHIVE_PATH = $(BUILD_DIR)/$(SCHEME).xcarchive
APP_PATH = $(BUILD_DIR)/MBOMail.app
EXPORT_OPTIONS = ExportOptions.plist

.PHONY: build archive export dmg clean

build:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) \
		-destination 'platform=macOS' \
		-configuration Release build

archive:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) \
		-destination 'platform=macOS' \
		-configuration Release \
		-archivePath $(ARCHIVE_PATH) archive

export: archive
	xcodebuild -exportArchive \
		-archivePath $(ARCHIVE_PATH) \
		-exportOptionsPlist $(EXPORT_OPTIONS) \
		-exportPath $(BUILD_DIR)

dmg: export
	./scripts/create-dmg.sh $(APP_PATH)

clean:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) clean
	rm -rf $(BUILD_DIR)
