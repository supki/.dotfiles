self: super:
let
  buildZshPlugin = { name, src }:
    super.stdenv.mkDerivation {
      inherit name src;

      installPhase = ''
        runHook preInstall
        target=$out/share/zsh/${name}
        mkdir -p $target
        cp -r . $target
        runHook postInstall
      '';
    };
in
rec {
  zsh-autosuggestions = buildZshPlugin {
    name = "zsh-autosuggestions";
    src = super.fetchFromGitHub {
      owner = "zsh-users";
      repo = "zsh-autosuggestions";
      rev = "master";
      sha256 = "sha256-KLUYpUu4DHRumQZ3w59m9aTW6TBKMCXl2UcKi4uMd7w=";
    };
  };
  zsh-syntax-highlighting = buildZshPlugin {
    name = "zsh-syntax-highlighting";
    src = super.fetchFromGitHub {
      owner = "zsh-users";
      repo = "zsh-syntax-highlighting";
      rev = "master";
      sha256 = "sha256-YV9lpJ0X2vN9uIdroDWEize+cp9HoKegS3sZiSpNk50=";
    };
  };
  neovim =
    let
      customVimPlugins = {
        vim-bling = super.vimUtils.buildVimPlugin {
          name = "vim-bling";
          src = super.fetchFromGitHub {
            owner = "ivyl";
            repo = "vim-bling";
            rev = "master";
            sha256 = "sha256-iJ/uaoq71IM1hQSrnZ86MBlpUWRp9vs1Grd1+9C1QFM=";
          };
        };
        vim-languages = super.vimUtils.buildVimPlugin {
          name = "vim-languages";
          src = super.fetchFromGitHub {
            owner = "supki";
            repo = "vim-languages";
            rev = "master";
            sha256 = "sha256-Dd7GwlGZoVG2VLu+2uLRR11BROZSgiJRuO0quEYofW0=";
          };
        };
        vim-init = super.vimUtils.buildVimPlugin {
         name = "vim-init";
         src = ../../nvim;
        };
      };
    in
      super.neovim.override {
        vimAlias = true;
        configure = {
          customRC = ''
            lua require("init")
          '';
          packages.myVimPackage = with super.vimPlugins // customVimPlugins; {
            start = let
              nvim-treesitter-with-plugins = nvim-treesitter.withPlugins (
                plugins: [
                  plugins.tree-sitter-haskell
                  plugins.tree-sitter-json
                  plugins.tree-sitter-lua
                  plugins.tree-sitter-nix
                  plugins.tree-sitter-yaml
                ]
              );
            in [
              # init.lua
              vim-init

              fzf-vim
              gitsigns-nvim
              golden-ratio
              nightfox-nvim
              nvim-treesitter-with-plugins
              nvim-ts-rainbow
              vim-airline
              vim-airline-themes
              vim-bling
              vim-commentary
              vim-languages
              vim-sandwich

              # fallback for treesitter failures
              haskell-vim
              vim-nix
            ];
            opt = [
            ];
          };
        };
      };
  stack = (
    self.writeScriptBin "stack" ''
      #!${self.runtimeShell}

      xdg_config_home_config_yaml=''${XDG_CONFIG_HOME:-$HOME/.config}/stack/config.yaml
      stack_root=$HOME/.stack
      stack_root_config_yaml=$stack_root/config.yaml
      if [ -f "$xdg_config_home_config_yaml" ]; then
        mkdir -p "$stack_root"
        cp "$xdg_config_home_config_yaml" "$stack_root_config_yaml"
      fi

      exec "${super.stack}/bin/stack" "$@"
    ''
  ) // {
    name = "stack";
    version = super.stack.version;
  };
  x-selection-sync = self.stdenv.mkDerivation {
    name = "x-selection-sync";
    src = self.fetchFromGitHub {
      owner = "supki";
      repo = "x-selection-sync";
      rev = "master";
      sha256 = "sha256-w/nt6LKB8QbM8GxkiI7DcS4xNqhVfR/LKznWjQ2qle8=";
    };
    buildInputs = [
      self.pkg-config
      self.xorg.libX11
      self.xorg.libXfixes
    ];
    installPhase = ''
      runHook preInstall
      target=$out/bin
      mkdir -p $target
      cp ./build/x-selection-sync $target
      runHook postInstall
    '';
  };
  haskellPackages = super.haskellPackages.override (_: {
    overrides = self.haskell.lib.packageSourceOverrides {
      dazu = self.fetchFromGitHub {
        owner = "supki";
        repo = "da";
        rev = "main";
        sha256 = "sha256-wmvwcwhAxlkoD2m+b8YDaqWETeoAjyWqZw7OKrSI9Bk=";
      };
    };
  });
  m-env = super.buildEnv {
    name = "m-env";
    paths = with super; [
      # packages I want
      alacritty
      diff-so-fancy
      dig
      feh
      fira-code
      git
      haskellPackages.dazu
      htop
      iotop
      jq
      moreutils
      mpv
      neovim
      nodejs
      pass
      scrot
      shellcheck
      stack
      tmux
      transmission-gtk
      tree
      x-selection-sync
      xsel
      yarn
      zellij
      zsh
      zsh-autosuggestions
      zsh-syntax-highlighting

      # packages Nix wants
      glibcLocales
      self.nixgl.nixGLIntel
    ];
  };
}
