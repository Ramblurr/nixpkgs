{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.davis;
  webserver = config.services.nginx;

  #pkg = cfg.package.override {
  #  inherit (cfg) dataDir configDir;
  #};
  pkgs = cfg.package;

  user = "davis";
  group = webserver.group;
in {
  options.services.davis = {
    enable = mkEnableOption (lib.mdDoc "Davis is a caldav and carddav server");

    user = mkOption {
      default = "davis";
      description = lib.mdDoc "User davis runs as.";
      type = types.str;
    };

    group = mkOption {
      default = "davis";
      description = lib.mdDoc "Group davis runs as.";
      type = types.str;
    };

    package = mkPackageOption pkgs "davis" {};
    #package = mkOption {
    #  type = types.package;
    #  default = pkgs.davis;
    #  defaultText = literalExpression "pkgs.davis";
    #  description = lib.mdDoc "Which davis package to use.";
    #};

    configDir = mkOption {
      type = types.path;
      default = "/etc/davis/";
      description = lib.mdDoc ''
        Davis configuration directory. Mostly managed via admin panel.
      '';
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/davis/";
      description = lib.mdDoc ''
        Davis data directory.
      '';
    };

    hostname = mkOption {
      type = types.str;
      default = "${user}.${config.networking.fqdnOrHostName}";
      defaultText = literalExpression ''
        "${user}.''${config.${options.networking.fqdnOrHostName}}"
      '';
      example = "davis.yourdomain.org";
      description = lib.mdDoc ''
        URL of the host, without https prefix. You may want to change it if you
        run Davis on a different URL than davis.yourdomain.
      '';
    };

    nginx = mkOption {
      type = types.submodule (
        recursiveUpdate
        (import ../web-servers/nginx/vhost-options.nix {inherit config lib;}) {}
      );
      default = null;
      example = ''
        {
          serverAliases = [
            "dav.''${config.networking.domain}"
          ];
          # To enable encryption and let let's encrypt take care of certificate
          forceSSL = true;
          enableACME = true;
        }
      '';
      description = lib.mdDoc ''
        With this option, you can customize the nginx virtualHost settings.
      '';
    };

    poolConfig = mkOption {
      type = with types; attrsOf (oneOf [str int bool]);
      default = {
        "pm" = "dynamic";
        "pm.max_children" = 32;
        "pm.start_servers" = 2;
        "pm.min_spare_servers" = 2;
        "pm.max_spare_servers" = 4;
        "pm.max_requests" = 500;
      };
      description = lib.mdDoc ''
        Options for the davis PHP pool. See the documentation on <literal>php-fpm.conf</literal>
        for details on configuration directives.
      '';
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [cfg.package];

    users = {
      users = mkIf (user == "davis") {
        davis = {
          inherit group;
          isSystemUser = true;
        };
        "${config.services.nginx.user}".extraGroups = [group];
      };
      groups = mkIf (group == "davis") {
        davis = {};
      };
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir}                            0710 ${user} ${group} - -"
      "d ${cfg.dataDir}/var                        0700 ${user} ${group} - -"
      "d ${cfg.dataDir}/var/log                    0700 ${user} ${group} - -"
      "d ${cfg.dataDir}/var/cache                  0700 ${user} ${group} - -"
    ];

    services.phpfpm.pools.davis = {
      inherit user group;
      phpOptions = ''
        log_errors = on
      '';
      settings =
        {
          "listen.mode" = "0660";
          "listen.owner" = user;
          "listen.group" = group;
        }
        // cfg.poolConfig;
    };

    # systemd.services."phpfpm-davis".serviceConfig.ReadWritePaths = [
    #   cfg.dataDir
    #   cfg.configDir
    # ];

    services.nginx.virtualHosts = mkIf (cfg.nginx != null) {
      "${cfg.hostname}" = mkMerge [
        cfg.nginx
        {
          # overriding this doesn't make sense as it will break davis
          root = mkForce "${pkg}/html/";
          extraConfig = ''
            charset utf-8;
          '';
          locations = {
            "/" = {
              extraConfig = ''
                try_files $uri $uri/ /index.php$is_args$args;
              '';
            };
            #"~* ^/.well-known/(caldav|carddav)$" = {
            #  extraConfig = ''
            #    return 302 $http_x_forwarded_proto://$host/dav/;
            #  '';
            #};
            #"~ ^(.+\.php)(.*)$" = {
            #  extraConfig = ''
            #    try_files                $fastcgi_script_name =404;
            #    include                  ${config.services.nginx.package}/conf/fastcgi_params;
            #    include                  ${config.services.nginx.package}/conf/fastcgi.conf;
            #    fastcgi_index            index.php;
            #    fastcgi_pass             unix:${config.services.phpfpm.pools.davis.socket};
            #    fastcgi_param            SCRIPT_FILENAME  $document_root$fastcgi_script_name;
            #    fastcgi_param            PATH_INFO        $fastcgi_path_info;
            #    fastcgi_split_path_info  ^(.+\.php)(.*)$;
            #    fastcgi_param            X-Forwarded-Proto $http_x_forwarded_proto;
            #    fastcgi_param            X-Forwarded-Port $http_x_forwarded_port;
            #  '';
            #};
            #"~ /(\\.ht)" = {
            #  extraConfig = ''
            #    deny all;
            #    return 404;
            #  '';
            #};
          };
        }
      ];
    };
  };

  #meta = {
  #doc = ./davis.md;
  #maintainers = with lib.maintainers; [ ramblurr ];
  #};
}
