# Project-level configuration.
cmake_minimum_required(VERSION 3.14)
project(mistream LANGUAGES CXX)

# The name of the executable created for the application. Change this to change
# the on-disk name of your application.
set(BINARY_NAME "mistream")

# Explicitly opt in to modern CMake behaviors to avoid warnings with recent
# versions of CMake.
cmake_policy(VERSION 3.14...3.25)

# Define build configuration option.
get_property(IS_MULTICONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if(IS_MULTICONFIG)
  set(CMAKE_CONFIGURATION_TYPES "Debug;Profile;Release"
    CACHE STRING "" FORCE)
else()
  if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE "Debug" CACHE
      STRING "Flutter build mode" FORCE)
    set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS
      "Debug" "Profile" "Release")
  endif()
endif()
# Define settings for the Profile build mode.
set(CMAKE_EXE_LINKER_FLAGS_PROFILE "${CMAKE_EXE_LINKER_FLAGS_RELEASE}")
set(CMAKE_SHARED_LINKER_FLAGS_PROFILE "${CMAKE_SHARED_LINKER_FLAGS_RELEASE}")
set(CMAKE_C_FLAGS_PROFILE "${CMAKE_C_FLAGS_RELEASE}")
set(CMAKE_CXX_FLAGS_PROFILE "${CMAKE_CXX_FLAGS_RELEASE}")

# Use Unicode for all projects.
add_definitions(-DUNICODE -D_UNICODE)

# Compilation settings that should be applied to most targets.
#
# Be cautious about adding new options here, as plugins use this function by
# default. In most cases, you should add new options to specific targets instead
# of modifying this function.
function(APPLY_STANDARD_SETTINGS TARGET)
  target_compile_features(${TARGET} PUBLIC cxx_std_17)
  target_compile_options(${TARGET} PRIVATE /W4 /WX /wd"4100")
  target_compile_options(${TARGET} PRIVATE /EHsc)
  target_compile_definitions(${TARGET} PRIVATE "_HAS_EXCEPTIONS=0")
  target_compile_definitions(${TARGET} PRIVATE "$<$<CONFIG:Debug>:_DEBUG>")
endfunction()

# Flutter library and tool build rules.
set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter")
add_subdirectory(${FLUTTER_MANAGED_DIR})

# Application build; see runner/CMakeLists.txt.
add_subdirectory("runner")

# Build and validate the AOT Spider JS runtime for distributable builds.
# Debug builds keep using the Dart source fallback so CI does not require local
# QuickJS binaries. Profile/Release fail hard when the runtime cannot be built.
get_filename_component(REPO_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../../.." ABSOLUTE)
find_program(POWERSHELL_EXECUTABLE NAMES pwsh powershell)
if(NOT POWERSHELL_EXECUTABLE)
  message(FATAL_ERROR "PowerShell is required to build the Spider JS runtime")
endif()

set(SPIDER_JS_BUILD_SCRIPT "${REPO_ROOT}/tools/build_spider_js_runtime.ps1")
set(SPIDER_JS_OUTPUT_DIR "${CMAKE_BINARY_DIR}/runner/$<CONFIG>")
add_custom_target(spider_js_runtime_bundle ALL
  COMMAND "${POWERSHELL_EXECUTABLE}"
    -NoProfile
    -ExecutionPolicy Bypass
    -File "${SPIDER_JS_BUILD_SCRIPT}"
    -Configuration "$<CONFIG>"
    -OutputDirectory "${SPIDER_JS_OUTPUT_DIR}"
  COMMENT "Building Spider JS runtime bundle"
  VERBATIM)
add_dependencies(${BINARY_NAME} spider_js_runtime_bundle)

# Copy libmpv-2.dll next to the executable after each build.
set(LIBMPV_SRC "${CMAKE_SOURCE_DIR}/../../build/libmpv/libmpv-2.dll")
if(EXISTS "${LIBMPV_SRC}")
  add_custom_command(TARGET ${BINARY_NAME} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
      "${LIBMPV_SRC}"
      "$<TARGET_FILE_DIR:${BINARY_NAME}>/libmpv-2.dll"
    COMMENT "Copying libmpv-2.dll to output directory")
endif()


# Generated plugin build rules, which manage building the plugins and adding
# them to the application.
include(flutter/generated_plugins.cmake)


# === Installation ===
# Support files are copied into place next to the executable, so that it can
# run in place. This is done instead of making a separate bundle (as on Linux)
# so that building and running from within Visual Studio will work.
set(BUILD_BUNDLE_DIR "$<TARGET_FILE_DIR:${BINARY_NAME}>")
# Make the "install" step default, as it's required to run.
set(CMAKE_VS_INCLUDE_INSTALL_TO_DEFAULT_BUILD 1)
if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  set(CMAKE_INSTALL_PREFIX "${BUILD_BUNDLE_DIR}" CACHE PATH "..." FORCE)
endif()

set(INSTALL_BUNDLE_DATA_DIR "${CMAKE_INSTALL_PREFIX}/data")
set(INSTALL_BUNDLE_LIB_DIR "${CMAKE_INSTALL_PREFIX}")

install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_ICU_DATA_FILE}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
  COMPONENT Runtime)

if(PLUGIN_BUNDLED_LIBRARIES)
  install(FILES "${PLUGIN_BUNDLED_LIBRARIES}"
    DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
    COMPONENT Runtime)
endif()

# Copy the native assets provided by the build.dart from all packages.
set(NATIVE_ASSETS_DIR "${PROJECT_BUILD_DIR}native_assets/windows/")
install(DIRECTORY "${NATIVE_ASSETS_DIR}"
   DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
   COMPONENT Runtime)

# Fully re-copy the assets directory on each build to avoid having stale files
# from a previous install.
set(FLUTTER_ASSET_DIR_NAME "flutter_assets")
install(CODE "
  file(REMOVE_RECURSE \"${INSTALL_BUNDLE_DATA_DIR}/${FLUTTER_ASSET_DIR_NAME}\")
  " COMPONENT Runtime)
install(DIRECTORY "${PROJECT_BUILD_DIR}/${FLUTTER_ASSET_DIR_NAME}"
  DESTINATION "${INSTALL_BUNDLE_DATA_DIR}" COMPONENT Runtime)

# Install the AOT library on non-Debug builds only.
install(FILES "${AOT_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  CONFIGURATIONS Profile;Release
  COMPONENT Runtime)

# Copy libmpv-2.dll next to the executable if present.
set(LIBMPV_PATH "${CMAKE_SOURCE_DIR}/../../build/libmpv/libmpv-2.dll")
if(EXISTS "${LIBMPV_PATH}")
  install(FILES "${LIBMPV_PATH}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
    COMPONENT Runtime)
endif()

set(SPIDER_JS_BUNDLE_DIR "${REPO_ROOT}/build/spider_js")
install(FILES
  "${SPIDER_JS_BUNDLE_DIR}/spider_js_runtime.exe"
  "${SPIDER_JS_BUNDLE_DIR}/libquickjs.dll"
  "${SPIDER_JS_BUNDLE_DIR}/quickjs_wrapper.dll"
  "${SPIDER_JS_BUNDLE_DIR}/quickjs.dll"
  DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
  CONFIGURATIONS Profile;Release
  COMPONENT Runtime)

# Spider JVM 运行时（实验性可选组件，定位见 docs/adr/006）。
#
# 包内布局必须与 AppAssembly._resolveJvmConfig() 的查找约定严格一致 —— 它按
# `<exe 目录>/runtimes/spider_jvm/` 找下面这两样，启动命令是
# `java -cp <jar>;<libs>/* io.mistream.jvm.Main`：
#   runtimes/spider_jvm/build/spider_jvm_runtime.jar
#   runtimes/spider_jvm/libs/*.jar
#
# ⚠️ 这条规则曾经**完全不存在**。后果不是「少个可选功能」，而是 0.1.0 的便携包
# 里一个 csp_ 站点都用不了：`_resolveJvmConfig()` 返回 null → supports(jvm)=false
# → 站点列表把 105 个站点全部灰显成「(暂不支持)」。用户的报告是「获取的 105 个
# 站点全部显示不支持」，根因就在这几行的缺失。
#
# 为什么是 OPTIONAL 而不是像 spider_js 那样硬失败：`build/`（根 .gitignore 第 6 行
# 的 `build/` 命中）与 `libs/` 都不入库，jar 由 `melos run jvm:build` 现场编译、
# 需要外部 JDK 17。ADR-006 把它定为「实验性可选组件」，因此没装 JDK 的本地构建
# 不该被它拦死。真正的兜底是发布门禁 tools/check_jvm_runtime_bundle.dart ——
# 发布链产物缺 jar 会直接红，本地构建则只在这里留一条可见的线索。
set(SPIDER_JVM_DIR "${REPO_ROOT}/runtimes/spider_jvm")
set(SPIDER_JVM_JAR "${SPIDER_JVM_DIR}/build/spider_jvm_runtime.jar")
if(EXISTS "${SPIDER_JVM_JAR}")
  message(STATUS "Spider JVM 运行时：已纳入产物（${SPIDER_JVM_JAR}）")
else()
  message(STATUS
    "Spider JVM 运行时：未构建（${SPIDER_JVM_JAR} 不存在）——本次产物不含 JVM 支持，"
    "csp_ 站点会显示「暂不支持」。先跑 `melos run jvm:build`（需 JDK 17）再构建。")
endif()

install(FILES "${SPIDER_JVM_JAR}"
  DESTINATION "${INSTALL_BUNDLE_LIB_DIR}/runtimes/spider_jvm/build"
  CONFIGURATIONS Profile;Release
  COMPONENT Runtime
  OPTIONAL)

install(DIRECTORY "${SPIDER_JVM_DIR}/libs"
  DESTINATION "${INSTALL_BUNDLE_LIB_DIR}/runtimes/spider_jvm"
  CONFIGURATIONS Profile;Release
  COMPONENT Runtime
  OPTIONAL)
