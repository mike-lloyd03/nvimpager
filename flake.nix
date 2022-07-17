{
  description = "Developmet flake for nvimpager";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    neovim-dev.url = "github:neovim/neovim?dir=contrib";
    neovim-070.url = "github:neovim/neovim?dir=contrib&ref=v0.7.0";
    neovim-071.url = "github:neovim/neovim?dir=contrib&ref=v0.7.1";
    neovim-072.url = "github:neovim/neovim?dir=contrib&ref=v0.7.2";
    neovim-dev.inputs.nixpkgs.follows = "nixpkgs";
    neovim-070.inputs.nixpkgs.follows = "nixpkgs";
    neovim-071.inputs.nixpkgs.follows = "nixpkgs";
    neovim-072.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, flake-utils, ... }@inputs: {
    overlay = final: prev: {
      nvimpager = prev.nvimpager.overrideAttrs (oa: {
        version = "dev";
        src = ./.;
        preBuild = "version=$(bash ./nvimpager -v | sed 's/.* //')";
        buildFlags = oa.buildFlags ++ [ "VERSION=\${version}-dev" ];
      });
    };
  }
  // (let
    inherit (nixpkgs.lib.strings) hasPrefix hasSuffix concatStringsSep;
    inherit (nixpkgs.lib.attrsets) filterAttrs mapAttrs mapAttrsToList;
    inherit (flake-utils.lib) eachSystem defaultSystems;
    systems = builtins.filter (s: !hasSuffix "-darwin" s) defaultSystems;
  in eachSystem systems (system:
  let
    pkgs = import nixpkgs { overlays = [ self.overlay ]; inherit system; };
    neovim-packages =
      mapAttrs (_: f: f.defaultPackage.${system})
               (filterAttrs (n: _: hasPrefix "neovim-" n) inputs);
    mkShell = with-neovim-versions: pkgs.mkShell {
      inputsFrom = [ pkgs.nvimpager ];
      packages = with pkgs; [
        lua51Packages.luacov
        git
        tmux
        hyperfine
      ] ++ pkgs.lib.lists.optional with-neovim-versions
                                   self.packages.${system}.neovim-versions;
      shellHook = ''
        # to find nvimpager lua code in the current dir
        export LUA_PATH=./?.lua''${LUA_PATH:+\;}$LUA_PATH
        # fix for different terminals in a pure shell
        export TERM=xterm
      '';
    };
  in rec {
    packages = {
      nvimpager = pkgs.nvimpager;
      neovim-versions = pkgs.stdenv.mkDerivation {
        pname = "neovim-versions";
        version = "all";
        dontUnpack = true;
        installPhase = ''
          mkdir -p $out/bin
          ${concatStringsSep "\n"
              (mapAttrsToList (n: p: "ln -s ${p}/bin/nvim $out/bin/${n}")
              neovim-packages)}
        '';
      };
    };
    defaultPackage = pkgs.nvimpager;
    apps.nvimpager = flake-utils.lib.mkApp { drv = pkgs.nvimpager; };
    defaultApp = apps.nvimpager;
    devShell = mkShell false;
    devShells.with-neovim-versions = mkShell true;
    devShells.default = mkShell false;
  }));
}
