{ pkgs, config, inputs, lib, ... }:

{
  # Aliases, it's necessary to set APP_URL for the watchers, otherwise the
  # hot-proxy throws `Client sent an HTTP request to an HTTPS server.`
  scripts.kill.exec = "kill $(ps -ax | grep /nix/store)";
  scripts.bstf.exec = "shopware-cli project storefront-build --only-custom-static-extensions";
  scripts.wstf.exec = "shopware-cli project storefront-watch --only-custom-static-extensions";
  scripts.wadm.exec = ''
     echo "Watching admin for plugin: $1"
     echo "Plugin Path: custom/static-plugins/$1"
     shopware-cli extension admin-watch "custom/static-plugins/$1"  http://127.0.0.1 --external-url http://127.0.0.1:8080;
  '';
  scripts.badm.exec = ''
     echo "Building admin for plugin: $1"
     shopware-cli extension build "custom/static-plugins/$1";
  '';
  scripts.zipext.exec = ''
     echo "Zip admin for plugin: $1"
     echo "Plugin Path: custom/static-plugins/$1"
     shopware-cli extension zip "custom/static-plugins/$1" --disable-git;
  '';
}