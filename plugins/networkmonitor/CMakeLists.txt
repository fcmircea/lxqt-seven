# Standalone build of lxqt-panel 2.3.2's networkmonitor plugin, patched to show
# the negotiated link speed in its tooltip. Installs to a user plugin folder that
# lxqt-panel searches first when LXQTPANEL_PLUGIN_PATH points at it.
cmake_minimum_required(VERSION 3.18)
project(lxqt-panel_networkmonitor CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTOUIC ON)
set(CMAKE_AUTORCC ON)

find_package(Qt6Widgets 6.6.0 REQUIRED)
# No liblxqt: the plugin only forward-declares LXQt types, and lxqt's CMake
# config would pull in KF6WindowSystem's dev package for nothing.
find_library(STATGRAB_LIB statgrab REQUIRED)

set(D plugin-networkmonitor)
add_library(networkmonitor MODULE
    ${D}/lxqtnetworkmonitorplugin.cpp
    ${D}/lxqtnetworkmonitor.cpp
    ${D}/lxqtnetworkmonitorconfiguration.cpp
    ${D}/lxqtnetworkmonitorconfiguration.ui
    ${D}/resources.qrc
)
target_link_libraries(networkmonitor Qt6::Widgets ${STATGRAB_LIB})

install(TARGETS networkmonitor DESTINATION "$ENV{HOME}/.local/lib/lxqt-panel")
