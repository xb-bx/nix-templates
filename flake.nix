{
  description = "templates";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }: {
    lib.mkDotnetApp = { projectName, projectVersion, src, dotnetSdk, nugetHash, targetSystem ? "x86_64-linux" }:
      let
        buildSystem = "x86_64-linux";
        pkgs = nixpkgs.legacyPackages.${buildSystem};
        csprojPath = "${src}/${projectName}.csproj";
        fsprojPath = "${src}/${projectName}.fsproj";
        
        projectFile = if builtins.pathExists csprojPath
          then "./${projectName}.csproj"
          else if builtins.pathExists fsprojPath
          then "./${projectName}.fsproj"
          else throw "Could not find a valid .csproj or .fsproj for ${projectName} in the source root.";

        nugetCache = pkgs.stdenv.mkDerivation {
          name = "${pkgs.lib.strings.toLower projectName}-nuget-cache";
          inherit src; 
          
          nativeBuildInputs = [ dotnetSdk pkgs.nukeReferences ];
          outputHashAlgo = "sha256";
          outputHashMode = "recursive";
          
          # Directly using the passed argument here
          outputHash = nugetHash; 

          buildPhase = ''
            export HOME=$TMPDIR
            # Ensure $out exists even when the project has no NuGet
            # dependencies (a framework-only restore downloads nothing).
            mkdir -p $out
            dotnet restore ${projectFile} \
              --source https://api.nuget.org/v3/index.json \
              --packages $out
          '';
          installPhase = ''
            find $out -type f -exec nuke-refs {} +
          '';
        };
      in
      pkgs.stdenv.mkDerivation {
        pname = pkgs.lib.strings.toLower projectName;
        version = projectVersion;
        inherit src;

        nativeBuildInputs = [ dotnetSdk pkgs.git ];

        buildPhase = ''
          export HOME=$TMPDIR
          export DOTNET_CLI_HOME=$TMPDIR
          dotnet restore ${projectFile} --source ${nugetCache}
          dotnet publish ${projectFile} \
            -c Release \
            --source ${nugetCache} \
            --no-restore \
            -o $out/share/${projectName}
        '';

        installPhase = "true";
      };
  };
}
