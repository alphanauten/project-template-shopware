{ pkgs, lib, config, inputs, ... }:

let
  pcov = config.languages.php.package.buildEnv {
    extensions = { all, enabled }: with all; (builtins.filter (e: e.extensionName != "blackfire" && e.extensionName != "xdebug") enabled) ++ [config.languages.php.package.extensions.pcov];
    extraConfig = config.languages.php.ini;
  };

  shopwareCliPackage = if builtins.hasAttr "froshpkgs" inputs
      then inputs.froshpkgs.packages.${pkgs.system}.shopware-cli
      else pkgs.shopware-cli;
in {
  packages = [
    pkgs.gnupatch
    pkgs.nodePackages_latest.yalc
    pkgs.gnused
    pkgs.symfony-cli
    pkgs.deno
    pkgs.jq
    pkgs.ludtwig
    ( pkgs.writeShellScriptBin "php-pcov" ''
      export PHP_INI_SCAN_DIR=''${PHP_INI_SCAN_DIR-'${pcov}/lib'}
      exec -a "$0" "${pcov}/bin/.php-wrapped"  "$@"
    '')
  ];

  # Fix .env loading
  process.manager.implementation = lib.mkDefault "honcho";

  dotenv.disableHint = true;

  languages.javascript = {
    enable = lib.mkDefault true;
    package = lib.mkDefault pkgs.nodejs_22;
  };

  languages.php = {
    enable = lib.mkDefault true;
    version = lib.mkDefault "8.3";
    extensions = [ "grpc" ];

    ini = ''
      memory_limit = 2G
      realpath_cache_ttl = 3600
      session.gc_probability = 0
      ${lib.optionalString config.services.redis.enable ''
      session.save_handler = redis
      session.save_path = "tcp://127.0.0.1:${toString config.services.redis.port}/0"
      ''}
      display_errors = On
      error_reporting = E_ALL
      assert.active = 0
      opcache.memory_consumption = 256M
      opcache.interned_strings_buffer = 20
      zend.assertions = 0
      short_open_tag = 0
      zend.detect_unicode = 0
      realpath_cache_ttl = 3600
      post_max_size = 32M
      upload_max_filesize = 32M
    '';

    fpm.pools.web = lib.mkDefault {
      settings = {
        "clear_env" = "no";
        "pm" = "dynamic";
        "pm.max_children" = 10;
        "pm.start_servers" = 2;
        "pm.min_spare_servers" = 1;
        "pm.max_spare_servers" = 10;
      };
    };
  };

  services.caddy = {
    enable = lib.mkDefault true;

    virtualHosts.":8000" = lib.mkDefault {
      extraConfig = lib.mkDefault ''
        @default {
          not path /theme/* /media/* /thumbnail/* /bundles/* /css/* /fonts/* /js/* /sitemap/*
        }

        encode zstd gzip
        root * public
        php_fastcgi @default unix/${config.languages.php.fpm.pools.web.socket} {
            trusted_proxies private_ranges
        }
        file_server
        encode

        encode zstd gzip
      '';
    };
  };

    services.mysql = {
      enable = true;
      package = pkgs.mariadb_106;
      initialDatabases = lib.mkDefault [{ name = "shopware"; }];
      ensureUsers = lib.mkDefault [
        {
          name = "shopware";
          password = "shopware";
          ensurePermissions = {
            "shopware.*" = "ALL PRIVILEGES";
            "shopware_test.*" = "ALL PRIVILEGES";
          };
        }
      ];
      settings = {
        mysqld = {
          group_concat_max_len = 320000;
          log_bin_trust_function_creators = 1;
          sql_mode = "STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION";
        };
      };
    };


  services.redis.enable = lib.mkDefault true;
  # WSL2 fix locale
  services.redis.extraConfig = "locale-collate C";
  services.adminer.enable = lib.mkDefault true;
  services.adminer.package = lib.mkDefault pkgs.adminerevo;
  services.adminer.listen = lib.mkDefault "127.0.0.1:9080";
  services.mailpit.enable = lib.mkDefault true;

  # services.opensearch.enable = true;
  # services.rabbitmq.enable = true;
  # services.rabbitmq.managementPlugin.enable = true;

  env.SHOPWARE_PROJECT_ROOT = builtins.toString ./.;

  # Elasticsearch
  env.OPENSEARCH_URL = lib.mkDefault "http://localhost:9200";
  env.ADMIN_OPENSEARCH_URL = lib.mkDefault "http://localhost:9200";

  # General cypress
  env.CYPRESS_baseUrl = lib.mkDefault "http://localhost:8000";

  # Installer/Updater testing
  env.INSTALL_URL = lib.mkDefault "http://localhost:8050";
  env.CYPRESS_dbHost = lib.mkDefault "localhost";
  env.CYPRESS_dbUser = lib.mkDefault "shopware";
  env.CYPRESS_dbPassword = lib.mkDefault "shopware";
  env.CYPRESS_dbName = lib.mkDefault "shopware";
}