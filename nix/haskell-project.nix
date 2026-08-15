{inputs, ...}: {
  imports = [
    {
      perSystem = {system, ...}: {
        # Inject haskell.nix overlay
        _module.args.pkgs = import inputs.nixpkgs {
          inherit system;
          overlays = [inputs.haskell-nix.overlay];
        };
      };
    }
  ];

  perSystem = {
    config,
    lib,
    pkgs,
    ...
  }: let
    inherit (pkgs.stdenv.hostPlatform) isx86_64 isLinux;

    crossPlatforms = p:
      lib.optionals isx86_64 [p.mingwW64]
      ++ lib.optionals (isx86_64 && isLinux) [p.musl64];

    cabalProject = pkgs.haskell-nix.cabalProject' {
      src = ./..;
      compiler-nix-name = "ghc912";
      name = "hydra-pleco";

      shell = {
        tools = {
          cabal = "latest";
          haskell-language-server = "latest";
        };

        buildInputs = with pkgs; [
          statix # nix static analysis
          deadnix # nix dead-code detector
          hlint # Haskell static analysis
        ];
        inputsFrom = [config.treefmt.build.devShell];

        withHoogle = true;

        # We don't need cross platforms in the shell; should speed up evaluation
        crossPlatforms = _: [];
      };

      modules = [
        # openapi3/servant-openapi3 ship `custom-setup` to run cabal-doctest, which causes
        # the following error:
        #
        #     error: The option `packages."Cabal-3.12.1.0-inplace".package.license' was
        #     accessed but has no value defined. Try setting the option.
        #
        # We don't run its doctests, so force a Simple setup.
        {
          packages.openapi3.package.buildType = lib.mkForce "Simple";
          packages.servant-openapi3.package.buildType = lib.mkForce "Simple";
        }
      ];
    };

    # Add exes to cabal project
    haskellProject = cabalProject.appendOverlays [
      pkgs.haskell-nix.haskellLib.projectOverlays.projectComponents
    ];

    # Flake with cross builds
    haskellFlake = haskellProject.flake {
      inherit crossPlatforms;
    };

    # Flake without cross builds; We don't need to run tests on them
    nativeFlake = haskellProject.flake {
      crossPlatforms = _: [];
    };
  in {
    # expose haskellProject to other modules
    _module.args.haskellProject = haskellProject;

    inherit (haskellFlake) packages apps;
    inherit (nativeFlake) checks devShells;
  };
}
