#
# macos — helpers for setting a Mac up.
#
#   install_pkg URL                      download and install a .pkg
#   install_dmg_pkg URL VOLUME PKG       mount a .dmg and install the .pkg in it
#   install_dmg URL VOLUME APP           mount a .dmg and copy the .app out
#   install_app_zip URL APP              download a .zip and unpack it into /Applications
#   backup_if_exists PATH                move it aside with a timestamp
#   link_if_different ACTUAL LINK        symlink, backing up whatever was there
#   clone_repo REPO PARENT               clone with gh, or fetch and pull if it is there
#   _add_dock_persistent_app APP         pin an app to the Dock
#   _add_dock_spacer                     add a Dock spacer
#   _delete_dock_apps                    clear the pinned apps
#
# Provisioning, not daily use: most of it wants sudo and the network, and the
# Dock ones need `killall Dock` afterwards to take effect. Nothing runs at load
# time.
#
# Defined only on macOS. hdiutil, installer, defaults and com.apple.dock exist
# nowhere else, so this plugin is a no-op on any other system rather than a
# collection of commands that fail when called.
#
[[ $OSTYPE == darwin* ]] || return 0

fpath=( ${${(%):-%x}:A:h}/functions $fpath )

autoload -Uz \
  install_pkg install_dmg_pkg install_dmg install_app_zip \
  backup_if_exists link_if_different clone_repo \
  _add_dock_persistent_app _add_dock_spacer _delete_dock_apps
