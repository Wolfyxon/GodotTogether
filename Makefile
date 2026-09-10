# This Makefile is only necessary to build a optimized release build.
# The plugin will work when put in the addons dir without being "built".

BUILD_ROOT_DIR := build
BUILD_DIR_NAME := GodotTogether
BUILD_FILES_DIR := $(BUILD_ROOT_DIR)/$(BUILD_DIR_NAME)
ZIP_PATH := $(BUILD_ROOT_DIR)/GodotTogether.zip

ESSENTIAL_ROOT_PATHS := src plugin.cfg .gitignore install_instructions.txt LICENSE

.PHONY: release build clean

release: build
	rm -f $(ZIP_PATH)
	
#	 Files directly in the zip
	cd $(BUILD_FILES_DIR) && zip -r ../../$(ZIP_PATH) .
	
#	 "GodotTogether" as root directory. (For future use, nicer for drag and drop install)
#	cd $(BUILD_ROOT_DIR) && zip -r ../$(ZIP_PATH) $(BUILD_DIR_NAME)
	
	@echo ""
	@echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
	@echo " Make sure create a .gdsig signature if you're publishing this!"
	@echo " Otherwise auto update will NOT work!"
	@echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
	@echo ""

build:
	mkdir -p $(BUILD_FILES_DIR)
	touch $(BUILD_ROOT_DIR)/.gdignore
	
	cp -r $(ESSENTIAL_ROOT_PATHS) $(BUILD_FILES_DIR)

clean:
	rm -rf $(BUILD_ROOT_DIR)
