{
  description = "templates";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }: {
    lib.mkDotnetApp = { projectName, projectVersion, src, dotnetSdk }: 
      let
        system = "x86_64-linux";
        pkgs = nixpkgs.legacyPackages.${system};
        csprojFile = "./${projectName}.csproj";

        # The generic, self-contained cache block using the passed SDK
        nugetCache = pkgs.stdenv.mkDerivation {
          name = "${pkgs.lib.strings.toLower projectName}-nuget-cache";
          inherit src; 
          
          nativeBuildInputs = [ dotnetSdk ];
          outputHashAlgo = "sha256";
          outputHashMode = "recursive";
          outputHash = pkgs.lib.fakeHash; 

          buildPhase = ''
            export HOME=$TMPDIR
            dotnet restore ${csprojFile} \
              --source https://api.nuget.org/v3/index.json \
              --packages $out
          '';
          installPhase = "true";
        };
      in
      pkgs.stdenv.mkDerivation {
        pname = pkgs.lib.strings.toLower projectName;
        version = projectVersion;
        inherit src;

        # Expose the specific cache block so it can be overridden downstream
        passthru = { inherit nugetCache; };

        nativeBuildInputs = [ dotnetSdk pkgs.git ];

        buildPhase = ''
          export HOME=$TMPDIR
          export DOTNET_CLI_HOME=$TMPDIR
          dotnet restore ${csprojFile} --source ${nugetCache}
          dotnet publish ${csprojFile} \
            -c Release \
            --source ${nugetCache} \
            --no-restore \
            -o $out/share/${projectName}
        '';

        installPhase = "true";
      };
  };
}
