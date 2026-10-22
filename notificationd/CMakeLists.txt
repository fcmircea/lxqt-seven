# Standalone build of lxqt-notificationd 2.3.1, patched so a timed-out notification
# with action buttons stays open behind the tray icon instead of closing, and long
# words wrap. Installs to ~/.local/bin; the autostart override in lxqt/ starts it
# in place of the system copy. Translations come from the installed package.
cmake_minimum_required(VERSION 3.18)
project(lxqt-notificationd CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTOUIC ON)
set(CMAKE_INCLUDE_CURRENT_DIR ON)

find_package(Qt6DBus 6.6.0 REQUIRED)
find_package(Qt6Widgets 6.6.0 REQUIRED)
find_package(KF6WindowSystem 6.0.0 REQUIRED)
find_package(lxqt 2.3.0 REQUIRED)
find_package(LayerShellQt 6.0.0 REQUIRED)

include(LXQtTranslationLoader)

add_definitions("-DLXQT_NOTIFICATIOND_VERSION=\"2.3.1-seven\"")

qt6_add_dbus_adaptor(DBUS_SRC src/org.freedesktop.Notifications.xml src/notifyd.h Notifyd)
set_property(SOURCE ${DBUS_SRC} PROPERTY SKIP_AUTOGEN ON)

lxqt_app_translation_loader(QM_LOADER ${PROJECT_NAME})

add_executable(lxqt-notificationd
    src/main.cpp
    src/notificationarea.cpp
    src/notification.cpp
    src/notification.ui
    src/notificationlayout.cpp
    src/notificationwidgets.cpp
    src/notifyd.cpp
    ${DBUS_SRC}
    ${QM_LOADER}
)
target_include_directories(lxqt-notificationd PRIVATE src)
target_link_libraries(lxqt-notificationd
    Qt6::Widgets
    Qt6::DBus
    lxqt
    KF6::WindowSystem
    LayerShellQtInterface
)

install(TARGETS lxqt-notificationd DESTINATION "$ENV{HOME}/.local/bin")
