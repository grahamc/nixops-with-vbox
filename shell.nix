let
  pkgs = import <nixpkgs> {};
  my-nixops-with-vbox = pkgs.poetry2nix.mkPoetryEnv {
    projectDir = ./.;
    overrides = pkgs.poetry2nix.overrides.withDefaults (
      self: super: {
        zipp = super.zipp.overridePythonAttrs (
          old: {
            propagatedBuildInputs = old.propagatedBuildInputs ++ [
              self.toml
            ];
          }
        );

        nixops = super.nixops.overridePythonAttrs (
          old: {
            format = "pyproject";
            buildInputs = old.buildInputs ++ [ self.poetry ];
          }
        );

        nixopsvbox = super.nixopsvbox.overridePythonAttrs (
          old: {
            format = "pyproject";
            buildInputs = old.buildInputs ++ [ self.poetry ];
          }
        );
      }
    );

  };
in
pkgs.mkShell {
  buildInputs = [
    my-nixops-with-vbox
  ];

  NIXOPS_DEPLOYMENT = "nixops-with-vbox";
  NIX_PATH = "nixpkgs=channel:nixos-unstable-small";
}
