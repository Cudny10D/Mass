cmake_minimum_required(VERSION 3.24)

project(ArknightsMusicPlayer LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS
    Core Gui Widgets Quick QuickControls2 Network Multimedia
)

qt_policy(SET QTP0001 NEW)
qt_policy(SET QTP0004 NEW)

qt_standard_project_setup()

qt_add_executable(ArknightsMusicPlayer
    main.cpp
    src/NetworkManager.cpp
    src/NetworkManager.h
    src/AudioEngine.cpp
    src/AudioEngine.h
    src/StreamAudioPlayer.cpp
    src/StreamAudioPlayer.h
    src/AudioCache.cpp
    src/AudioCache.h
    src/AudioMetadataProbe.cpp
    src/AudioMetadataProbe.h
    src/CoverCache.cpp
    src/CoverCache.h
    src/TranslationService.cpp
    src/TranslationService.h
    src/Settings.cpp
    src/Settings.h
    src/HistoryManager.cpp
    src/HistoryManager.h
    src/PlaylistManager.cpp
    src/PlaylistManager.h
    src/SystemTrayManager.cpp
    src/SystemTrayManager.h
)

# ============================================================
# Windows 资源
# ============================================================
if(WIN32)
    set(APP_ICON "${CMAKE_CURRENT_SOURCE_DIR}/icon.ico")

    if(EXISTS "${APP_ICON}")
        set(RC_FILE "${CMAKE_CURRENT_BINARY_DIR}/app_icon.rc")

        file(WRITE "${RC_FILE}"
            "IDI_ICON1 ICON DISCARDABLE \"${APP_ICON}\"\n"
            "\n"
            "VS_VERSION_INFO VERSIONINFO\n"
            "FILEVERSION 1,0,0,0\n"
            "PRODUCTVERSION 1,0,0,0\n"
            "FILEFLAGSMASK 0x3fL\n"
            "FILEFLAGS 0x0L\n"
            "FILEOS 0x40004L\n"
            "FILETYPE 0x1L\n"
            "FILESUBTYPE 0x0L\n"
            "BEGIN\n"
            "    BLOCK \"StringFileInfo\"\n"
            "    BEGIN\n"
            "        BLOCK \"080404b0\"\n"
            "        BEGIN\n"
            "            VALUE \"CompanyName\",      \"Cudny\\0\"\n"
            "            VALUE \"FileDescription\",  \"Mass\\0\"\n"
            "            VALUE \"FileVersion\",      \"1.0.0.0\\0\"\n"
            "            VALUE \"InternalName\",     \"Mass\\0\"\n"
            "            VALUE \"LegalCopyright\",   \"Copyright (C) 2026 Cudny\\0\"\n"
            "            VALUE \"OriginalFilename\", \"ArknightsMusicPlayer.exe\\0\"\n"
            "            VALUE \"ProductName\",      \"Mass\\0\"\n"
            "            VALUE \"ProductVersion\",   \"1.0.0.0\\0\"\n"
            "        END\n"
            "    END\n"
            "    BLOCK \"VarFileInfo\"\n"
            "    BEGIN\n"
            "        VALUE \"Translation\", 0x0804, 1200\n"
            "    END\n"
            "END\n"
        )

        target_sources(ArknightsMusicPlayer PRIVATE "${RC_FILE}")
        message(STATUS "App icon + version info: ${APP_ICON}")
    else()
        message(WARNING "icon.ico not found, exe will use default icon")
    endif()
endif()

set_source_files_properties(qml/Theme.qml
    PROPERTIES QT_QML_SINGLETON_TYPE TRUE
)

qt_add_qml_module(ArknightsMusicPlayer
    URI ArknightsMusicPlayer
    VERSION 1.0
    QML_FILES
        Main.qml
        qml/Theme.qml
        qml/TitleBar.qml
        qml/SideBar.qml
        qml/SirenPage.qml
        qml/SearchPage.qml
        qml/HistoryPage.qml
        qml/PlaylistPage.qml
        qml/PlaylistPickerDialog.qml
        qml/SettingsPage.qml
        qml/PlayerBar.qml
        qml/PlaylistPanel.qml
        qml/FullPlayer.qml
        qml/DesktopLyric.qml
)

qt_add_resources(ArknightsMusicPlayer "app_resources"
    PREFIX "/"
    FILES
        resources/app.ico
)

target_include_directories(ArknightsMusicPlayer PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/src
)

target_link_libraries(ArknightsMusicPlayer PRIVATE
    Qt6::Core Qt6::Gui Qt6::Widgets
    Qt6::Quick Qt6::QuickControls2
    Qt6::Network Qt6::Multimedia
)

set_target_properties(ArknightsMusicPlayer PROPERTIES
    WIN32_EXECUTABLE TRUE
)