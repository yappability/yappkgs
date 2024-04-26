{ stdenvNoCC, lib, pkgs, ... }:
stdenvNoCC.mkDerivation rec {
  version = "1.1.4";
  pname = "bun";

  src = passthru.sources.${stdenvNoCC.hostPlatform.system} or (throw
    "Unsupported system: ${stdenvNoCC.hostPlatform.system}");

  strictDeps = true;
  nativeBuildInputs = with pkgs; [ unzip installShellFiles ]
    ++ lib.optionals stdenvNoCC.isLinux [ autoPatchelfHook ];
  buildInputs = with pkgs; [ openssl ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm 755 ./bun $out/bin/bun
    ln -s $out/bin/bun $out/bin/bunx

    runHook postInstall
  '';

  postPhases = [ "postPatchelf" ];
  postPatchelf = lib.optionalString
    (stdenvNoCC.buildPlatform.canExecute stdenvNoCC.hostPlatform) ''
    completions_dir=$(mktemp -d)

    SHELL="bash" $out/bin/bun completions $completions_dir
    SHELL="zsh" $out/bin/bun completions $completions_dir
    SHELL="fish" $out/bin/bun completions $completions_dir

    installShellCompletion --name bun \
      --bash $completions_dir/bun.completion.bash \
      --zsh $completions_dir/_bun \
      --fish $completions_dir/bun.fish
  '';

  passthru = {
    sources = {
      "aarch64-darwin" = pkgs.fetchurl {
        url = "https://github.com/oven-sh/bun/releases/download/bun-v1.1.5/bun-darwin-aarch64.zip";
        hash = "sha256-cn4pjaYUeXWo/CqTZsZTRLfETI6Qizp8JosBw9yQocU=";
      };
      "aarch64-linux" = pkgs.fetchurl {
        url = "https://github.com/oven-sh/bun/releases/download/bun-v1.1.5/bun-linux-aarch64.zip";
        hash = "sha256-Kooxd0VOOz5i4O2e+BKbG41CiH2vqOMWgIVgsU8DPms=";
      };
      "x86_64-darwin" = pkgs.fetchurl {
        url = "https://github.com/oven-sh/bun/releases/download/bun-v1.1.5/bun-darwin-x64-baseline.zip";
        hash = "sha256-JtkrOqRAFxjH5oFr/j+N/LxNNi7GRXwPlGmctxWkdiA=";
      };
      "x86_64-linux" = pkgs.fetchurl {
        url =
          "https://github.com/oven-sh/bun/releases/download/bun-v1.1.5/bun-linux-x64-baseline.zip";
        hash =
          "sha256-GTVoxk7wchTiJqCRJkspLJGXwKD92+ZYT7UBWMhONkQ=";
      };
    };
    };
    updateScript = pkgs.writeShellScript "update-bun" ''
      set -o errexit
      export PATH="${lib.makeBinPath [ pkgs.curl pkgs.jq pkgs.common-updater-scripts ]}"
      NEW_VERSION=$(curl --silent https://api.github.com/repos/oven-sh/bun/releases/latest | jq '.tag_name | ltrimstr("bun-v")' --raw-output)
      if [[ "${version}" = "$NEW_VERSION" ]]; then
          echo "The new version same as the old version."
          exit 0
      fi
      for platform in ${lib.escapeShellArgs meta.platforms}; do
        update-source-version "bun" "0" "${lib.fakeHash}" --source-key="sources.$platform"
        update-source-version "bun" "$NEW_VERSION" --source-key="sources.$platform"
      done
    '';
  };
  meta = {
    homepage = "https://bun.sh";
    changelog = "https://bun.sh/blog/bun-v${version}";
    description =
      "Incredibly fast JavaScript runtime, bundler, transpiler and package manager – all in one";
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    longDescription = ''
      All in one fast & easy-to-use tool. Instead of 1,000 node_modules for development, you only need bun.
    '';
    license = with lib.licenses; [
      mit # bun core
      lgpl21Only # javascriptcore and webkit
    ];
    mainProgram = "bun";
    maintainers = [ "yusof" ];
    platforms = builtins.attrNames passthru.sources;
    # Broken for Musl at 2024-01-13, tracking issue:
    # https://github.com/NixOS/nixpkgs/issues/280716
    broken = stdenvNoCC.hostPlatform.isMusl;
  };
}

