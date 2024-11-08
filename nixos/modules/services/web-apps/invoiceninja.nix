{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.invoiceninja;
  user = cfg.user;
  group = cfg.group;
  invoiceninja = cfg.package.override { inherit (cfg) dataDir runtimeDir; };

  extraPrograms = [
    # these are used for invoice PDF generation
    pkgs.ungoogled-chromium
    pkgs.freefont_ttf
    pkgs.xorg.fontisasmisc
    pkgs.dejavu_fonts
  ];

  phpPackage = cfg.phpPackage.buildEnv {
    extensions = (
      { enabled, all }:
      enabled
      ++ (with all; [
        memcached
        bcmath
        ctype
        fileinfo
        gd
        mbstring
        openssl
        pdo
        tokenizer
        curl
        zip
        gmp
        iconv
        mysqli
        intl
        pdo_mysql
        exif
        opcache
      ])
    );
  };
  configFile = pkgs.writeText "invoiceninja-env" (lib.generators.toKeyValue { } cfg.environment);
  invoiceninja-manage = pkgs.writeShellScriptBin "invoiceninja-manage" ''
    cd ${invoiceninja}/share/invoiceninja
    sudo=exec
    if [[ "$USER" != ${user} ]]; then
      sudo='exec /run/wrappers/bin/sudo -u ${user}'
    fi
    $sudo ${phpPackage}/bin/php artisan "$@"
  '';
  dbSocket = "/run/mysqld/mysqld.sock";
  dbService = "mysql.service";
  redisService = "redis-invoiceninja.service";

  sharedRestartTriggers = [
    cfg.environmentFile
    configFile
  ];

  sharedServiceConfig = {
    ReadWritePaths = [
      cfg.dataDir
      cfg.runtimeDir
    ];
    CapabilityBoundingSet = "~CAP_SYS_ADMIN";
    DeviceAllow = "";
    LockPersonality = true;
    NoNewPrivileges = true;
    PrivateDevices = true;
    PrivateTmp = true;
    PrivateUsers = true;
    ProcSubset = "pid";
    ProtectClock = true;
    ProtectControlGroups = true;
    ProtectHome = true;
    ProtectHostname = true;
    ProtectKernelLogs = true;
    ProtectKernelModules = true;
    ProtectKernelTunables = true;
    ProtectProc = "invisible";
    ProtectSystem = "strict";
    RemoveIPC = true;
    RestrictNamespaces = true;
    RestrictRealtime = true;
    RestrictSUIDSGID = true;
    SystemCallArchitectures = "native";
    SystemCallFilter = [
      "@system-service"
      "~@resources"
      "~@privileged"
    ];
  };
in
{
  options.services = {
    invoiceninja = {
      enable = lib.mkEnableOption (lib.mdDoc "a Invoice Ninja instance");
      package = lib.mkPackageOption pkgs "invoiceninja" { };
      phpPackage = lib.mkPackageOption pkgs "php82" { };

      user = lib.mkOption {
        type = lib.types.str;
        default = "invoiceninja";
        description = lib.mdDoc ''
          User account under which invoiceninja runs.

          ::: {.note}
          If left as the default value this user will automatically be created
          on system activation, otherwise you are responsible for
          ensuring the user exists before the invoiceninja application starts.
          :::
        '';
      };

      group = lib.mkOption {
        type = lib.types.str;
        default = "invoiceninja";
        description = lib.mdDoc ''
          Group account under which invoiceninja runs.

          ::: {.note}
          If left as the default value this group will automatically be created
          on system activation, otherwise you are responsible for
          ensuring the group exists before the invoiceninja application starts.
          :::
        '';
      };

      domain = lib.mkOption {
        type = lib.types.str;
        description = lib.mdDoc ''
          FQDN for the Invoice Ninja instance.
        '';
      };

      environmentFile = lib.mkOption {
        type = lib.types.path;
        description = lib.mdDoc ''
          A secret file in .env format, to be sourced for the .env settings.
          Place `APP_KEY` and other settings that should not end up in the Nix store here.
        '';
      };

      environment = lib.mkOption {
        type = (
          lib.types.attrsOf (
            lib.types.oneOf [
              lib.types.bool
              lib.types.int
              lib.types.str
            ]
          )
        );
        description = lib.mdDoc ''
          .env settings for Invoice Ninja.
          Secrets should use `environmentFile` option instead.
        '';
      };

      trustedProxies = lib.mkOption {
        description = lib.mdDoc ''
          A list of CIDRs that are trusted to act as a reverse proxy and forward requests to Invoice Ninja.
        '';
        type = lib.types.listOf lib.types.str;
        default = [ "127.0.0.1/32" ];
      };

      nginx = lib.mkOption {
        type = lib.types.nullOr (
          lib.types.submodule (import ../web-servers/nginx/vhost-options.nix { inherit config lib; })
        );
        default = null;
        example = lib.literalExpression ''
          {
            serverAliases = [
              "invoices.''${config.networking.domain}"
            ];
            enableACME = true;
            forceHttps = true;
          }
        '';
        description = lib.mdDoc ''
          With this option, you can customize an nginx virtual host which already has sensible defaults.
          Set to {} if you do not need any customization to the virtual host.
          If enabled, then by default, the {option}`serverName` is
          `''${domain}`,
          If this is set to null (the default), no nginx virtualHost will be configured.
        '';
      };

      redis.createLocally =
        lib.mkEnableOption (lib.mdDoc "a local Redis database using UNIX socket authentication")
        // {
          default = true;
        };

      database = {
        createLocally =
          lib.mkEnableOption (lib.mdDoc "a local database using UNIX socket authentication")
          // {
            default = true;
          };
        automaticMigrations =
          lib.mkEnableOption (
            lib.mdDoc "automatic migrations for database schema and data (initial migration will be performed regardless)"
          )
          // {
            default = true;
          };

        name = lib.mkOption {
          type = lib.types.str;
          default = "invoiceninja";
          description = lib.mdDoc "Database name.";
        };
      };

      maxUploadSize = lib.mkOption {
        type = lib.types.str;
        default = "8M";
        description = lib.mdDoc ''
          Max upload size with units.
        '';
      };

      poolConfig = lib.mkOption {
        type =
          with lib.types;
          attrsOf (oneOf [
            int
            str
            bool
          ]);
        default = { };

        description = lib.mdDoc ''
          Options for Invoice Ninja's PHP-FPM pool.
        '';
      };

      dataDir = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/invoiceninja";
        description = lib.mdDoc ''
          State directory of the `invoiceninja` user which holds
          the application's state and data.
        '';
      };

      runtimeDir = lib.mkOption {
        type = lib.types.str;
        default = "/run/invoiceninja";
        description = lib.mdDoc ''
          Ruutime directory of the `invoiceninja` user which holds
          the application's caches and temporary files.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.invoiceninja = lib.mkIf (cfg.user == "invoiceninja") {
      isSystemUser = true;
      group = cfg.group;
      extraGroups = lib.optional cfg.redis.createLocally "redis-invoiceninja";
    };
    users.groups.invoiceninja = lib.mkIf (cfg.group == "invoiceninja") { };

    services.redis.servers.invoiceninja.enable = lib.mkIf cfg.redis.createLocally true;
    services.invoiceninja.environment = lib.mkMerge [
      ({
        APP_ENV = lib.mkDefault "production";
        APP_DEBUG = lib.mkDefault false;
        APP_URL = lib.mkDefault "https://${cfg.domain}";
        LOG_CHANNEL = lib.mkDefault "stack";
        MAIL_MAILER = lib.mkDefault "log";
        TRUSTED_PROXIES = lib.mkDefault (lib.concatStringsSep "," cfg.trustedProxies);
        PHANTOMJS_PDF_GENERATION = lib.mkDefault false;
        SNAPPDF_SKIP_DOWNLOAD = lib.mkDefault true;
        SNAPPDF_CHROMIUM_PATH = lib.mkDefault (lib.getExe pkgs.ungoogled-chromium);
        PDF_GENERATOR = lib.mkDefault "snappdf";
        SENTRY_LARAVEL_DSN = lib.mkDefault ""; # prevent phoning home
        LOCAL_DOWNLOAD = lib.mkDefault true;
        PRECONFIGURED_INSTALL = lib.mkDefault true; # this is required to bypass the setup db setup screen
      })
      (lib.mkIf (cfg.redis.createLocally) {
        BROADCAST_DRIVER = lib.mkDefault "redis";
        CACHE_DRIVER = lib.mkDefault "redis";
        QUEUE_CONNECTION = lib.mkDefault "redis";
        SESSION_DRIVER = lib.mkDefault "redis";
        SESSION_CONNECTION = lib.mkDefault "default";
        WEBSOCKET_REPLICATION_MODE = lib.mkDefault "redis";
        REDIS_SCHEME = lib.mkDefault "unix";
        REDIS_HOST = lib.mkDefault config.services.redis.servers.invoiceninja.unixSocket;
        REDIS_PATH = lib.mkDefault config.services.redis.servers.invoiceninja.unixSocket;
      })
      (lib.mkIf (cfg.database.createLocally) {
        DB_SOCKET = lib.mkDefault dbSocket;
        DB_DATABASE = lib.mkDefault cfg.database.name;
        DB_USERNAME = lib.mkDefault user;
        DB_PORT = lib.mkDefault 0;
      })
    ];

    environment.systemPackages = [ invoiceninja-manage ];

    services.mysql = lib.mkIf (cfg.database.createLocally) {
      enable = lib.mkDefault true;
      package = lib.mkDefault pkgs.mariadb;
      ensureDatabases = [ cfg.database.name ];
      ensureUsers = [
        {
          name = user;
          ensurePermissions = {
            "${cfg.database.name}.*" = "ALL PRIVILEGES";
          };
        }
      ];
    };

    # Make each individual option overridable with lib.mkDefault.
    services.invoiceninja.poolConfig = lib.mapAttrs' (n: v: lib.nameValuePair n (lib.mkDefault v)) {
      "pm" = "dynamic";
      "php_admin_value[error_log]" = "stderr";
      "php_admin_flag[log_errors]" = true;
      "catch_workers_output" = true;
      "pm.max_children" = "32";
      "pm.start_servers" = "2";
      "pm.min_spare_servers" = "2";
      "pm.max_spare_servers" = "4";
      "pm.max_requests" = "500";
    };

    services.phpfpm.pools.invoiceninja = {
      inherit user group;
      inherit phpPackage;

      phpOptions = ''
        post_max_size = ${toString cfg.maxUploadSize}
        upload_max_filesize = ${toString cfg.maxUploadSize}
        max_execution_time = 600;
      '';

      settings = {
        "listen.owner" = user;
        "listen.group" = group;
        "listen.mode" = "0660";
        "catch_workers_output" = "yes";
      } // cfg.poolConfig;
    };

    systemd.services.phpfpm-invoiceninja.after = [ "invoiceninja-data-setup.service" ];
    systemd.services.phpfpm-invoiceninja.requires =
      [
        "invoiceninja-worker.service"
        "invoiceninja-data-setup.service"
      ]
      ++ lib.optional cfg.database.createLocally dbService
      ++ lib.optional cfg.redis.createLocally redisService;
    systemd.services.phpfpm-invoiceninja.path = extraPrograms;
    systemd.services.phpfpm-invoiceninja.restartTriggers = sharedRestartTriggers;
    systemd.services.phpfpm-invoiceninja.serviceConfig = {
      CapabilityBoundingSet = "~CAP_SYS_ADMIN";
    };
    systemd.services.invoiceninja-worker = {
      description = "Invoice Ninja queue worker";
      after = [
        "network.target"
        "invoiceninja-data-setup.service"
      ];
      requires =
        [ "invoiceninja-data-setup.service" ]
        ++ (lib.optional cfg.database.createLocally dbService)
        ++ (lib.optional cfg.redis.createLocally redisService);
      wantedBy = [ "multi-user.target" ];
      path = extraPrograms;
      restartTriggers = sharedRestartTriggers;
      serviceConfig = {
        Type = "simple";
        ExecStart = "${invoiceninja-manage}/bin/invoiceninja-manage queue:work --sleep=3 --tries=1 --memory=1024 --timeout=3600 --daemon";
        StateDirectory = lib.mkIf (cfg.dataDir == "/var/lib/invoiceninja") "invoiceninja";
        User = user;
        Group = group;
        Restart = "on-failure";
      } // sharedServiceConfig;
    };

    systemd.services.invoiceninja-scheduler = {
      description = "Invoice Ninja periodic tasks";
      path = extraPrograms;
      serviceConfig = {
        Type = "simple";
        ExecStart = "${invoiceninja-manage}/bin/invoiceninja-manage schedule:work";
        User = user;
        Group = group;
        StateDirectory = lib.mkIf (cfg.dataDir == "/var/lib/invoiceninja") "invoiceninja";
      } // sharedServiceConfig;
    };

    systemd.services.invoiceninja-data-setup = {
      description = "Invoice Ninja setup: migrations, environment file update, cache reload, data changes";
      wantedBy = [ "multi-user.target" ];
      after = lib.optional cfg.database.createLocally dbService;
      requires = lib.optional cfg.database.createLocally dbService;
      path =
        with pkgs;
        [
          bash
          invoiceninja-manage
          rsync
          pkgs.mariadb # for mysqldump and mysql (client)
        ]
        ++ extraPrograms;
      restartTriggers = sharedRestartTriggers;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = user;
        Group = group;
        StateDirectory = lib.mkIf (cfg.dataDir == "/var/lib/invoiceninja") "invoiceninja";
        LoadCredential = "env-secrets:${cfg.environmentFile}";
        UMask = "077";
      } // sharedServiceConfig;

      environment = {
        # a transitive dependency of invoiceninja/laravel, psysh (which we can't disable), wants write access to an xdg config dir
        # it writes an empty file to $XDG_CONFIG_HOME/psysh/psysh_history
        XDG_CONFIG_HOME = cfg.dataDir;
      };
      script = ''
        set -x
        # Before running any PHP program, cleanup the code cache.
        # It's necessary if you upgrade the application otherwise you might
        # try to import non-existent modules.
        echo "Clearing cache"
        rm -f ${cfg.runtimeDir}/app.php
        rm -rf ${cfg.runtimeDir}/cache/*
        rm -rf ${cfg.runtimeDir}/resources

        # Concatenate non-secret .env and secret .env
        echo "Building environment"
        rm -f ${cfg.dataDir}/.env
        cp --no-preserve=all ${configFile} ${cfg.dataDir}/.env
        echo -e '\n' >> ${cfg.dataDir}/.env
        cat "$CREDENTIALS_DIRECTORY/env-secrets" >> ${cfg.dataDir}/.env

        echo "Linking static resources"

        # Link the static storage (package provided) to the runtime storage
        mkdir -p ${cfg.dataDir}/storage ${cfg.dataDir}/storage-public
        rsync -aq --no-perms ${invoiceninja}/share/invoiceninja/storage-static/ ${cfg.dataDir}/storage
        chmod -R +w ${cfg.dataDir}/storage ${cfg.dataDir}/storage-public
        chmod g+x ${cfg.dataDir}/storage ${cfg.dataDir}/storage/app ${cfg.dataDir}/storage-public


        # Link the app.php in the runtime folder.
        ln -sf ${invoiceninja}/share/invoiceninja/bootstrap-static/app.php ${cfg.runtimeDir}/bootstrap/app.php

        # Link resources in the runtime folder - invoiceninja writes to it at runtime
        rsync -aq --no-perms ${invoiceninja}/share/invoiceninja/resources-static/ ${cfg.runtimeDir}/resources
        chmod -R +w ${cfg.runtimeDir}/resources

        echo "Running invoiceninja setup tasks"
        invoiceninja-manage config:cache
        invoiceninja-manage optimize
        invoiceninja-manage package:discover

        # Perform the first migration.
        set +e
        IN_INIT=$(invoiceninja-manage tinker --execute='echo Schema::hasTable("accounts") && !App\Models\Account::all()->first();')
        set -e
        if [ "$IN_INIT" == "1" ]; then
          echo "Performing first run migration, seeding, and optional account creation"
          invoiceninja-manage migrate --force
          invoiceninja-manage db:seed --force
        fi
        echo "Updating the invoiceninja react ui"
        invoiceninja-manage ninja:react

        ${lib.optionalString cfg.database.automaticMigrations ''
          echo "Running invoiceninja automatic migrations"
          invoiceninja-manage migrate --force
        ''}
      '';
    };

    systemd.tmpfiles.rules = [
      # Cache must live across multiple systemd units runtimes.
      "d ${cfg.runtimeDir}/                         0700 ${user} ${group} - -"
      "d ${cfg.runtimeDir}/resources                0700 ${user} ${group} - -"
      "d ${cfg.runtimeDir}/bootstrap                0700 ${user} ${group} - -"
      "d ${cfg.runtimeDir}/bootstrap/cache          0700 ${user} ${group} - -"
    ];

    # Allow NGINX to access our phpfpm-socket.
    users.users."${config.services.nginx.user}".extraGroups = [ cfg.group ];
    services.nginx = lib.mkIf (cfg.nginx != null) {
      enable = true;
      virtualHosts."${cfg.domain}" = lib.mkMerge [
        cfg.nginx
        {
          root = lib.mkForce "${invoiceninja}/share/invoiceninja/public/";
          locations."/".tryFiles = "$uri $uri/ /index.php?$query_string";
          locations."/favicon.ico".extraConfig = ''
            access_log off; log_not_found off;
          '';
          locations."/robots.txt".extraConfig = ''
            access_log off; log_not_found off;
          '';
          locations."~ \\.php$".extraConfig = ''
            fastcgi_split_path_info ^(.+\.php)(/.+)$;
            fastcgi_pass unix:${config.services.phpfpm.pools.invoiceninja.socket};
            fastcgi_index index.php;
          '';
          locations."~ /\\.(?!well-known).*".extraConfig = ''
            deny all;
          '';
          extraConfig = ''
            add_header X-Frame-Options "SAMEORIGIN";
            add_header X-XSS-Protection "1; mode=block";
            add_header X-Content-Type-Options "nosniff";
            index index.html index.htm index.php;
            error_page 404 /index.php;
            client_max_body_size ${toString cfg.maxUploadSize};
          '';
        }
      ];
    };
  };

  meta = {
    doc = ./invoiceninja.md;
    maintainers = pkgs.invoiceninja.meta.maintainers;
  };
}
