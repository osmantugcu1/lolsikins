cmake_minimum_required(VERSION 3.20)

project(lolsikins LANGUAGES CXX C)

set(CMAKE_C_STANDARD 99)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOUIC OFF)
set(CMAKE_AUTOMOC OFF)
set(CMAKE_AUTORCC OFF)

add_subdirectory(cslol-tools)

option(USE_QT6 "Use Qt6 instead of Qt5" OFF)
if (USE_QT6)
    find_package(Qt6 6.1 COMPONENTS Core Gui Quick QmlImportScanner Network REQUIRED)
else()
    find_package(Qt5 5.15 COMPONENTS Core Gui Quick QmlImportScanner Network REQUIRED)
endif()
find_package(Threads REQUIRED)
find_package(Git QUIET REQUIRED)

add_custom_command(
    OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/CSLOLversion.cpp"
    COMMAND "${GIT_EXECUTABLE}"
            "-C" "${CMAKE_SOURCE_DIR}"
            "log"
            "-1"
            "--output" "${CMAKE_CURRENT_BINARY_DIR}/CSLOLversion.cpp"
            "--date=short"
            "--format=\
#include <CSLOLVersion.h>%n\
char const* CSLOL::VERSION=\"%ad-%h\";%n\
char const* CSLOL::COMMIT=\"%H\";%n\
char const* CSLOL::DATE=\"%aI\";%n"
    DEPENDS "${CMAKE_SOURCE_DIR}/.git/index"
    VERBATIM
    )

if (WIN32)
    add_executable(LolSikins WIN32
        src/main.cpp
        src/res/rc.rc
        src/res/LolSikins.exe.manifest
    )
    target_link_libraries(LolSikins PRIVATE user32)
elseif(APPLE)
    set_source_files_properties(src/res/icon.icns
        PROPERTIES
        MACOSX_PACKAGE_LOCATION "Resources")
    add_executable(LolSikins MACOSX_BUNDLE
        src/main.cpp
        src/res/icon.icns
        )
    target_link_libraries(LolSikins PRIVATE "-framework Security")
    set_target_properties(LolSikins
        PROPERTIES
        MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/src/res/MacOSXBundleInfo.plist.in"
        MACOSX_BUNDLE_ICON_FILE icon
        MACOSX_BUNDLE_BUNDLE_NAME LolSikins
        MACOSX_BUNDLE_BUNDLE_VERSION "0.1"
        MACOSX_BUNDLE_SHORT_VERSION_STRING "0.1"
        MACOSX_BUNDLE_GUI_IDENTIFIER lolsikins.app
        )
    install(CODE [[
      include(BundleUtilities)
      fixup_bundle("${CMAKE_BINARY_DIR}/LolSikins.app" "" "")
    ]] COMPONENT Runtime)
else()
    add_executable(LolSikins
        src/main.cpp
    )
endif()

target_sources(LolSikins PRIVATE
    "${CMAKE_CURRENT_BINARY_DIR}/CSLOLversion.cpp"
    src/CSLOLTools.h
    src/CSLOLTools.cpp
    src/CSLOLToolsImpl.h
    src/CSLOLToolsImpl.cpp
    src/CSLOLUtils.h
    src/CSLOLUtils.cpp
    src/CSLOLSkinRepo.h
    src/CSLOLSkinRepo.cpp
    src/CSLOLVersion.h
    src/qml/qml.qrc
)

set_target_properties(LolSikins PROPERTIES AUTOUIC ON)
set_target_properties(LolSikins PROPERTIES AUTOMOC ON)
set_target_properties(LolSikins PROPERTIES AUTORCC ON)

target_compile_definitions(LolSikins PRIVATE $<$<OR:$<CONFIG:Debug>,$<CONFIG:RelWithDebInfo>>:QT_QML_DEBUG>)
target_link_libraries(LolSikins PRIVATE Qt::Core Qt::Gui Qt::Quick Qt::Network Threads::Threads)
target_include_directories(LolSikins PRIVATE src/)
if (MSVC)
    target_compile_options(LolSikins PRIVATE /utf-8)
endif()

qt_import_qml_plugins(LolSikins)
