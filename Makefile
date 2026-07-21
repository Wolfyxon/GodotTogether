# This Makefile is only necessary to build a optimized release build.
# The plugin will work when put in the addons dir without being "built".

BUILD_ROOT_DIR := build
BUILD_FILES_DIR := $(BUILD_ROOT_DIR)/source
ZIP_PATH := $(BUILD_ROOT_DIR)/GodotTogether.zip
SIGNATURE_PATH := $(ZIP_PATH).sig

ESSENTIAL_ROOT_PATHS := src plugin.cfg .gitignore LICENSE

.PHONY: release build sign clean

release: build
	rm -f $(ZIP_PATH)
	cd $(BUILD_FILES_DIR) && zip -r ../../$(ZIP_PATH) .

build:
	mkdir -p $(BUILD_FILES_DIR)
	touch $(BUILD_ROOT_DIR)/.gdignore
	
	cp -r $(ESSENTIAL_ROOT_PATHS) $(BUILD_FILES_DIR)

sign: release
	rm $(SIGNATURE_PATH)
	gpg --detach-sig $(ZIP_PATH)

clean:
	rm -rf $(BUILD_ROOT_DIR)
