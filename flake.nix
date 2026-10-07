{
  description = "datalab — categorized data-processing toolkits";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, nixpkgs-stable, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        pkgs-stable = import nixpkgs-stable { inherit system; };

        categories = {

          # SQL engines and database clients
          sql = with pkgs; [
            duckdb
            sqlite
          ];

          database = with pkgs; [
            postgresql
            redis
          ];

          # Structured data formats
          json = with pkgs; [
            jq
            jqp
            jless
            check-jsonschema
          ];

          yaml = with pkgs; [
            yq-go
            check-jsonschema
          ];

          xml = with pkgs; [
            libxml2
            libxslt
            saxon-he
            xmlstarlet
          ];

          csv = with pkgs; [
            xan
            csvlens
            csvkit
            miller
          ];

          # Text manipulation and search
          text = with pkgs; [
            gawk
            sd
            choose
            moreutils
          ];

          search = with pkgs; [
            ripgrep
            fd
          ];

          # Network I/O and data transfer
          network = with pkgs; [
            curl
            wget
            aria2
            rsync
            httpie
            xh
          ];

          # Object storage and S3-compatible services
          object-storage = with pkgs; [
            awscli2
            rclone
            s3cmd
            minio-client
          ];

          # Geospatial data
          geo = with pkgs; [
            gdal
            proj
          ];

          # Cryptography and secure data handling
          crypto = with pkgs; [
            openssl
            gnupg
            age
          ];

          # Documents, publishing, and technical writing
          docs = with pkgs; [
            pandoc
            glow
            typst

            # Scheme-medium keeps the closure manageable.
            texlive.combined.scheme-medium
          ];

          # Data visualization
          dataviz = with pkgs; [
            python314Packages.vl-convert-python
            youplot
            gnuplot
          ];

          # Cloud-specific tooling
          cloud = with pkgs; [
            awscli2
            rclone
          ];

          # Compression and archival
          compression = with pkgs; [
            gzip
            xz
            bzip2
            lz4
            zstd
            p7zip
            unzip
            zip
            gnutar
          ];

          # System utilities useful in data workflows
          system = with pkgs; [
            pv
            parallel
            time
            htop
          ];

          misc = with pkgs; [
            tree
          ];
        };

        mkEnv = name: paths:
          pkgs.buildEnv {
            name = "datalab-${name}";
            inherit paths;
          };

        categoryPackages = pkgs.lib.mapAttrs mkEnv categories;

        allTools = pkgs.lib.flatten (pkgs.lib.attrValues categories);

        banner = ''
          cat <<'BANNER'
           ____        _        _        _
          |  _ \  __ _| |_ __ _| |    __ _| |__
          | | | |/ _` | __/ _` | |   / _` | '_ \
          | |_| | (_| | || (_| | |__| (_| | |_) |
          |____/ \__,_|\__\__,_|_____\__,_|_.__/

          BANNER

          echo "categories: ${builtins.concatStringsSep ", " (builtins.attrNames categories)}"
          echo
          echo "Examples:"
          echo "  nix shell .#json"
          echo "  nix shell .#sql .#csv"
          echo "  nix develop .#network"
          echo
        '';

      in
      {
        packages = categoryPackages // {
          default = mkEnv "all" allTools;
        };

        devShells =
          pkgs.lib.mapAttrs
            (name: env:
              pkgs.mkShell {
                name = "datalab-${name}";
                packages = [ env ];
                shellHook = banner;
              }
            )
            categoryPackages
          // {
            default = pkgs.mkShell {
              name = "datalab";
              packages = allTools;
              shellHook = banner;
            };
          };
      }
    );
}
