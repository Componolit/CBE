LIBS    += spark aes_cbc_4k sha256_4k

INC_DIR += $(REP_DIR)/src/lib/cbe

SRC_ADS += cbe.ads

SRC_ADB += cbe-cxx-cxx_translation.adb
SRC_ADB += cbe-cxx-cxx_cache.adb
SRC_ADB += cbe-cxx-cxx_cache_flusher.adb
SRC_ADB += cbe-cxx-cxx_crypto.adb
SRC_ADB += cbe-cxx-cxx_pool.adb
SRC_ADB += cbe-cxx-cxx_splitter.adb
SRC_ADB += cbe-cxx-cxx_primitive.adb
SRC_ADB += cbe-cxx-cxx_request.adb
SRC_ADB += cbe-cxx-cxx_sync_superblock.adb
SRC_ADB += cbe-cxx-cxx_virtual_block_device.adb
SRC_ADB += cbe-cxx.adb
SRC_ADB += cbe-splitter.adb
SRC_ADB += cbe-primitive.adb
SRC_ADB += cbe-request.adb
SRC_ADB += cbe-pool.adb
SRC_ADB += cbe-crypto.adb
SRC_ADB += cbe-cache.adb
SRC_ADB += cbe-tree_helper.adb
SRC_ADB += cbe-translation.adb
SRC_ADB += cbe-cache_flusher.adb
SRC_ADB += cbe-sync_superblock.adb
SRC_ADB += cbe-virtual_block_device.adb
SRC_ADB += cbe-free_tree.adb

vpath % $(REP_DIR)/src/lib/cbe
