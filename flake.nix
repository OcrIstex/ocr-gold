{
  description = "OCR development environment - Tesseract 3.03rc1 + Leptonica 1.70 with pinned legacy libs, plus Tesseract 5 data";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      forAllSystems =
        f:
        nixpkgs.lib.genAttrs systems (
          system:
          f (
            import nixpkgs {
              inherit system;
            }
          )
        );
    in
    {
      packages = forAllSystems (
        pkgs:

        let
          oldLib =
            args:
            pkgs.stdenv.mkDerivation (
              {
                enableParallelBuilding = true;
                env.NIX_CFLAGS_COMPILE = toString [
                  "-w"
                  "-std=gnu99"
                  "-fpermissive"
                  "-Wno-error=implicit-function-declaration"
                  "-Wno-error=implicit-int"
                  "-Wno-error=int-conversion"
                  "-Wno-error=incompatible-pointer-types"
                ];
              }
              // args
            );

          zlib128 = oldLib {
            pname = "zlib";
            version = "1.2.8";
            src = pkgs.fetchurl {
              url = "https://zlib.net/fossils/zlib-1.2.8.tar.gz";
              hash = "sha256-NmWMt2ilTB1N7EPDEWwn7Yk+iLAuz8tE8hZvnAt/Kg0=";
            };
            configurePlatforms = [ ];
            dontAddStaticConfigureFlags = true;
            dontAddDisableDepTrack = true;
          };

          jpeg8d = oldLib {
            pname = "libjpeg";
            version = "8d";
            src = pkgs.fetchurl {
              url = "https://www.ijg.org/files/jpegsrc.v8d.tar.gz";
              hash = "sha256-/cTUwRM4rQKKfSP7U/W7k1RnE5Kmf7G1LgwypxIYkfg=";
            };
          };

          png1250 = oldLib {
            pname = "libpng";
            version = "1.2.50";
            src = pkgs.fetchurl {
              url = "https://downloads.sourceforge.net/project/libpng/libpng12/older-releases/1.2.50/libpng-1.2.50.tar.xz";
              hash = "sha256-RyT4H4ySrH82CtH78XM5bqfFNZI0JNufuv8Hv9nY6Oc=";
            };
            buildInputs = [ zlib128 ];
          };

          tiff403 = oldLib {
            pname = "libtiff";
            version = "4.0.3";
            src = pkgs.fetchurl {
              urls = [
                "https://mirrors.mit.edu/ubuntu/pool/main/t/tiff/tiff_4.0.3.orig.tar.gz"
                "https://mirror.its.umich.edu/pub/ubuntu/pool/main/t/tiff/tiff_4.0.3.orig.tar.gz"
                "https://launchpad.net/ubuntu/+archive/primary/+sourcefiles/tiff/4.0.3-7ubuntu0.3/tiff_4.0.3.orig.tar.gz"
              ];
              sha256 = "ea1aebe282319537fb2d4d7805f478dd4e0e05c33d0928baba76a7c963684872";
              name = "tiff-4.0.3.tar.gz";
            };
            buildInputs = [
              zlib128
              jpeg8d
            ];
            configureFlags = [
              "--disable-lzma"
              "--disable-jbig"
              "--disable-cxx"
              "--without-x"
            ];
          };

          giflib416 = oldLib {
            pname = "giflib";
            version = "4.1.6";
            src = pkgs.fetchurl {
              urls = [
                "https://launchpad.net/ubuntu/+archive/primary/+sourcefiles/giflib/4.1.6-11/giflib_4.1.6.orig.tar.gz"
                "https://deb.debian.org/debian/pool/main/g/giflib/giflib_4.1.6.orig.tar.gz"
                "https://mirrors.mit.edu/ubuntu/pool/main/g/giflib/giflib_4.1.6.orig.tar.gz"
                "https://mirror.its.umich.edu/pub/ubuntu/pool/main/g/giflib/giflib_4.1.6.orig.tar.gz"
              ];
              sha256 = "ceca77dcd29eb6f6d0336414dfecc9094413f71c3b589afcf96bb72fbfb08ce0";
              name = "giflib-4.1.6.tar.gz";
            };
            configureFlags = [ "--without-x" ];
          };

          webp040 = oldLib {
            pname = "libwebp";
            version = "0.4.0";
            src = pkgs.fetchurl {
              urls = [
                "https://launchpad.net/ubuntu/+archive/primary/+sourcefiles/libwebp/0.4.0-4/libwebp_0.4.0.orig.tar.gz"
                "https://deb.debian.org/debian/pool/main/libw/libwebp/libwebp_0.4.0.orig.tar.gz"
              ];
              hash = "sha256-MZE1d+ljhlVoVbQdIQc2RJRF/pbPvpKJAU6bivqUTWk=";
              name = "libwebp-0.4.0.tar.gz";
            };

            configureFlags = [
              "--disable-gl"
              "--disable-sdl"
            ];
          };

          oldLibs = [
            zlib128
            jpeg8d
            png1250
            tiff403
            giflib416
            webp040
          ];

          leptonica170 = pkgs.stdenv.mkDerivation {
            pname = "leptonica";
            version = "1.70";

            src = pkgs.fetchurl {
              url = "https://mirror.sobukus.de/files/grimoire/graphics/leptonica-1.70.tar.gz";
              hash = "sha256-09IJofbR96gBGUhrUBG8jGYn5YLJJ6tEujPDftss+6I=";
            };

            nativeBuildInputs = with pkgs; [
              autoconf
              automake
              libtool
              pkg-config
            ];

            buildInputs = oldLibs;

            configureFlags = [
              "--disable-programs"
              "--disable-doc"
            ];

            enableParallelBuilding = true;
          };

          # --- Tesseract 3 data (legacy models) -------------------------------
          engTraineddata3 = pkgs.fetchurl {
            url = "https://raw.githubusercontent.com/tesseract-ocr/tessdata/3.04.00/eng.traineddata";
            sha256 = "c0515c9f1e0c79e1069fcc05c2b2f6a6841fb5e1082d695db160333c1154f06d";
          };

          # --- Tesseract 5 data (LSTM, best quality) --------------------------
          # For the fast models use the tessdata_fast repo instead.
          engTraineddata5 = pkgs.fetchurl {
            url = "https://raw.githubusercontent.com/tesseract-ocr/tessdata_best/4.1.0/eng.traineddata";
            hash = "sha256-goCu0Hgv4nJXpo6hD+fvMkyg+Nhb0v0UXRwrVgvLZro=";
          };

          # TESSDATA_PREFIX for Tesseract 5 = directory that contains eng.traineddata
          tessdata5 = pkgs.runCommand "tessdata5" { } ''
            mkdir -p "$out"
            cp ${engTraineddata5} "$out/eng.traineddata"
          '';

          tesseract303 = pkgs.stdenv.mkDerivation {
            pname = "tesseract3";
            version = "3.03rc1";

            src = pkgs.fetchurl {
              url = "http://arch.p5n.pp.ru/~sergej/dl/2014/tesseract-3.03rc1.tar.gz";
              hash = "sha256-0kSVYjb3SR101/NCiV9hGmxGxF+pkAFz1bdiXYRh0uo=";
            };

            nativeBuildInputs = with pkgs; [
              autoconf
              automake
              libtool
              pkg-config
            ];

            buildInputs = [ leptonica170 ] ++ oldLibs;

            env.NIX_CFLAGS_COMPILE = "-fpermissive -w";

            postPatch = ''
              sed -i 's/to_win > 0/to_win != NULL/g' textord/topitch.cpp
            '';

            preConfigure = ''
              export CPPFLAGS="-I${leptonica170}/include -I${leptonica170}/include/leptonica"
              export LDFLAGS="-L${leptonica170}/lib"
              export LIBS="-llept -ljpeg -lpng -ltiff -lz"
              export LIBLEPT_HEADERSDIR="${leptonica170}/include"
              export PKG_CONFIG_PATH="${leptonica170}/lib/pkgconfig"
              ./autogen.sh
            '';

            configureFlags = [
              "--disable-shared"
              "--prefix=${placeholder "out"}"
            ];

            enableParallelBuilding = true;

            # TESSDATA_PREFIX for Tesseract 3 = parent of tessdata/ (= $out/share/)
            postInstall = ''
              mkdir -p "$out/share/tessdata"
              cp ${engTraineddata3} "$out/share/tessdata/eng.traineddata"
              mv "$out/bin/tesseract" "$out/bin/tesseract3"
            '';
          };

        in
        {
          tesseract3 = tesseract303;
          inherit tessdata5;
          default = tesseract303;
        }
      );

      devShells = forAllSystems (
        pkgs:

        let
          system = pkgs.stdenv.hostPlatform.system;
          tesseract3 = self.packages.${system}.tesseract3;
          tessdata5 = self.packages.${system}.tessdata5;

        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              tesseract3
              tesseract
              poppler-utils
              imagemagick
              fzf
              git
              less
            ];

            shellHook = ''
              # Tesseract 3: parent of tessdata/, trailing slash required
              export TESSDATA3="${tesseract3}/share/"
              # Tesseract 5: directory containing eng.traineddata
              export TESSDATA5="${tessdata5}"
              echo "TESSDATA3=$TESSDATA3"
              echo "TESSDATA5=$TESSDATA5"
            '';
          };
        }
      );
    };
}
