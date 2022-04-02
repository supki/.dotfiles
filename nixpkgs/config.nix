{
  packageOverrides = pkgs: with pkgs; rec {
    m-zsh-autosuggestions = stdenv.mkDerivation rec {
      name = "zsh-autosuggestions";
      src = pkgs.fetchFromGitHub {
        owner = "zsh-users";
        repo = "zsh-autosuggestions";
        rev = "master";
        sha256 = "sha256-KLUYpUu4DHRumQZ3w59m9aTW6TBKMCXl2UcKi4uMd7w=";
      };

      installPhase = ''
        runHook preInstall
        target=$out/share/zsh/${name}
        mkdir -p $target
        cp -r . $target
        runHook postInstall
      '';
    };
    m-zsh-syntax-highlighting = stdenv.mkDerivation rec {
      name = "zsh-syntax-highlighting";
      src = pkgs.fetchFromGitHub {
        owner = "zsh-users";
        repo = "zsh-syntax-highlighting";
        rev = "master";
        sha256 = "sha256-UqeK+xFcKMwdM62syL2xkV8jwkf/NWfubxOTtczWEwA=";
      };

      installPhase = ''
        runHook preInstall
        target=$out/share/zsh/${name}
        mkdir -p $target
        cp -r . $target
        runHook postInstall
      '';
    };
    m-neovim =
      let
        customVimPlugins = {
          vim-bling = pkgs.vimUtils.buildVimPlugin {
            name = "vim-bling";
            src = pkgs.fetchFromGitHub {
              owner = "ivyl";
              repo = "vim-bling";
              rev = "master";
              sha256 = "sha256-c0opD24dFBQxiYITOUKTyX0msqT5B3hMb2rKnPuLqEo=";
            };
          };
          vim-languages = pkgs.vimUtils.buildVimPlugin {
            name = "vim-languages";
            src = pkgs.fetchFromGitHub {
              owner = "supki";
              repo = "vim-languages";
              rev = "master";
              sha256 = "sha256-ThAkYrykRAwk/jWj3ymjxwSZKfnyJcOdB3lmPUJxLcc=";
            };
          };
        };
      in
        neovim.override {
          vimAlias = true;
          configure = {
            customRC = builtins.readFile ./init.vim;
            packages.myVimPackage = with pkgs.vimPlugins // customVimPlugins; {
              start = [
                fzf-vim
                golden-ratio
                haskell-vim
                rainbow_parentheses-vim
                seoul256-vim
                vim-airline
                vim-airline-themes
                vim-bling
                vim-commentary
                vim-languages
                vim-nix
                vim-sandwich
              ];
              opt = [
              ];
            };
          };
        };
    m-packages = pkgs.buildEnv {
      name = "m-packages";
      paths = [
        diff-so-fancy
        git
        htop
        jq
        pass
        m-neovim
        m-zsh-autosuggestions
        m-zsh-syntax-highlighting
        tmux
        zsh
      ];
    };
  };
}
