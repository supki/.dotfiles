{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}
module Main (main) where

import           Control.Lens
import           Data.Foldable (traverse_)
import           System.FilePath (combine)
import           Text.Printf (printf)

import           Control.Biegunka
import           Control.Biegunka.Source.Git (git, git', git_, branch)
import           Control.Biegunka.Templates.HStringTemplate

import qualified Laptop
import qualified Work


data E = Laptop | Work deriving (Enum, Bounded, Generic)

instance Environments E


main :: IO ()
main = do
  (environment, runBiegunka) <- runnerOf (Proxy :: Proxy E)
  let settings ts = set templates (hStringTemplate ts)
  case environment of
    Laptop -> runBiegunka (settings Laptop.template) laptop
    Work   -> runBiegunka (settings Work.template) work

laptop, work :: Script 'Sources ()
laptop = sudo "maksenov" $ sequence_
  [ dotfiles
  , tools
  , vim
  , emacs
  , misc
  , edwardk
  , mine
  , vimpager
  ]
work = sequence_
  [ dotfiles
  , vim
  , misc
  , edwardk
  , mine
  , vimpager
  ]

dotfiles :: Script 'Sources ()
dotfiles = namespace "dotfiles" $
  git (github "supki" ".dotfiles") "git/dotfiles" $ do
    traverse_ (uncurry link)
              (concat [core, extended, script])
    traverse_ (uncurry substitute)
              template
    nix
    [sh|DISPLAY=:0 xrdb -merge ~/.Xdefaults|]
    [sh|xmonad --recompile|]
    [sh|pakej --recompile|]
    let pathogen_url :: String
        pathogen_url = "https://raw.github.com/tpope/vim-pathogen/master/autoload/pathogen.vim"
    [sh|
      mkdir -p  ~/.vim/autoload ~/.vim/bundle ~/.vim/colors
      curl -o ~/.vim/autoload/pathogen.vim #{pathogen_url}
    |]
    [sh|lesskey|]
    [sh|chmod +x ~/.xsessionrc|]
    [sh|chmod '0600' "${SOURCE_ROOT}/core/ghci"|]
    [sh|
       cabal2nix "https://github.com/supki/pakej" > "nix/pakej.nix"
       cabal2nix "https://github.com/biegunka/biegunka" > "nix/biegunka.nix"
    |]
 where
  core = over (mapped._1) (combine "core")
    [ dot "mpdconf"
    , dot "profile"
    , dot "zshenv"
    , dot "zshrc"
    , dot "inputrc"
    , dot "vimrc"
    , dot "ghci"
    , dot "irbrc"
    , dot "haskeline"
    , dot "racketrc"
    , dot "gitconfig"
    , dot "gitignore"
    , dot "ackrc"
    , dot "XCompose"
    , dot "vimusrc"
    , dot "tmux.conf"
    , dot "emacs"
    , dot "poneaux.rb"
    , dot "sqliterc"
    , dot "pythonrc"
    , dot "curlrc"
    , dot "codorc"
    , dot "guard.rb"
    , dot "vim-jinjing"
    , dot "psqlrc"
    , dot "lesskey"
    , dot "colordiffrc"
    , dot "gtktermrc"
    , "vim/vim.custom"                    ~> ".vim/plugin/vimrc-local.vim"
    , "vim/indent/haskell.vim"            ~> ".vim/indent/haskell.vim"
    , "vim/camo.vim"                      ~> ".vim/colors/camo.vim"
    , "vim/zenburn.vim"                   ~> ".vim/colors/zenburn.vim"
    , "pakej.hs"                          ~> ".pakej/pakej.hs"
    , "vifmrc"                            ~> ".vifm/vifmrc"
    , "transmission-daemon/settings.json" ~> ".transmission-daemon/settings.json"
    , "profile"                           ~> ".xmonad/xmonad-session-rc"
    , "profile"                           ~> ".zprofile"
    ]
  extended = over (mapped._1) (combine "extended")
    [ dot "gvimrc"
    , dot "pentadactylrc"
    , dot "gtkrc.mine"
    , dot "readme-gen.css"
    , "xmonad.hs"                ~> ".xmonad/xmonad.hs"
    , "xmonad/Bindings.hs"       ~> ".xmonad/lib/Bindings.hs"
    , "xmonad/Startup.hs"        ~> ".xmonad/lib/Startup.hs"
    , "xmonad/Themes.hs"         ~> ".xmonad/lib/Themes.hs"
    , "xmonad/Tmux.hs"           ~> ".xmonad/lib/Tmux.hs"
    , "xmonad/Workspaces.hs"     ~> ".xmonad/lib/Workspaces.hs"
    , "xmonad/Spawn.hs"          ~> ".xmonad/lib/Spawn.hs"
    , "xmonad/PackagePrompt.hs"  ~> ".xmonad/lib/PackagePrompt.hs"
    , "pentadactyl/wanker.penta" ~> ".pentadactyl/plugins/wanker.penta"
    , "mplayer-config"           ~> ".mplayer/config"
    ]
  template = over (mapped._1) (combine "template")
    [ "xsession"                 ~> ".xsession"
    , "xsession"                 ~> ".xsessionrc"
    , "xmonad/Profile.hs"        ~> ".xmonad/lib/Profile.hs"
    , "xmodmap"                  ~> ".xmodmap"
    , "Xdefaults"                ~> ".Xdefaults"
    ]
  script = over (mapped._1) (combine "script")
    [ bin "bat.rb"
    , bin "ip.awk"
    , bin "weather.rb"
    , bin "dive-into-mail"
    , bin "svn-browse"
    , bin "whereami"
    ]
  nix = do
    link "nix/config.nix"         ".nixpkgs/config.nix"
    link "nix/hdevtools-7.8.nix"  ".nixpkgs/hdevtools-7.8.nix"
    link "nix/hdevtools-7.10.nix" ".nixpkgs/hdevtools-7.10.nix"
    link "nix/biegunka.nix"       ".nixpkgs/biegunka.nix"
    link "nix/pakej.nix"          ".nixpkgs/pakej.nix"

tools :: Script 'Sources ()
tools = namespace "tools" $
  git "git@budueba.com:tools" "git/tools" $ do
    suid_binaries & unzipWithM_ (\s t ->
      sudo "root" $ [sh|
        ghc -O #{s} -fforce-recomp -threaded -v0 -o #{t}
        chown root:root #{t}
        chmod +s #{t}
      |])
    user_binaries & unzipWithM_ (\s t -> do
      [sh|ghc -O #{s} -fforce-recomp -v0 -o #{t}|]
      link t (combine "bin" t))
    unzipWithM_ link scripts
 where
  scripts, user_binaries, suid_binaries :: [(String, String)]
  scripts =
    [ "youtube-in-mplayer.sh" ~> "bin/youtube-in-mplayer"
    , "cue2tracks.sh"         ~> "bin/cue2tracks"
    , "mpd/.lastfm.conf"      ~> ".lastfm.conf"
    , "mpd/lastfm.png"        ~> ".icons/lastfm.png"
    , "mpd/love.hs"           ~> "bin/lastfm-love-current-mpd-track"
    , "pemised.rb"            ~> "bin/pemised"
    , "upload/screenshot.sh"  ~> "bin/upload-screenshot"
    , "upload/budueba.sh"     ~> "bin/upload-budueba"
    , "isup.sh"               ~> "bin/isup"
    , "pretty-json.py"        ~> "bin/pretty-json"
    , "publish-haddocks.sh"   ~> "bin/publish-haddocks"
    , "vaio-audio"            ~> "bin/vaio-audio"
    , "vaio-touchpad"         ~> "bin/vaio-touchpad"
    , "suspender"             ~> "bin/suspender"
    ]
  user_binaries =
    [ "audio.hs"              ~> "vaio-audio"
    , "jenkins-hi.hs"         ~> "jenkins-hi"
    , "playcount.hs"          ~> "playcount"
    ]
  suid_binaries =
    [ "suspender.hs"          ~> "suspender"
    , "vaio/touchpad.hs"      ~> "vaio-touchpad"
    ]

vim :: Script 'Sources ()
vim = do
  namespace "vim" $ do
    namespace "haskell" $ do
      pathogen  (github "Shougo" "vimproc") $
        [sh|make -f make_unix.mak|]
      pathogen_ (github "eagletmt" "ghcmod-vim")
      pathogen_ (github "ujihisa" "neco-ghc")
      pathogen_ (github "Shougo" "neocomplcache")
      pathogen_ (github "bitc" "vim-hdevtools")
    namespace "coq" $ do
      pathogen_ (github "vim-scripts" "coq-syntax")
      pathogen_ (github "vim-scripts" "Coq-indent")
      pathogen_ (github "trefis" "coquille")
    namespace "misc" $ do
      pathogen_ (github "scrooloose" "syntastic")
      pathogen_ (github "tpope" "vim-commentary")
      pathogen_ (github "tpope" "vim-unimpaired")
      pathogen_ (github "def-lkb" "vimbufsync")
      pathogen_ (github "ivyl" "vim-bling")
      pathogen_ (github "kien" "rainbow_parentheses.vim")
      pathogen  (github "wincent" "Command-T") $
        [sh|cd $SOURCE_ROOT/ruby/command-t; /usr/bin/ruby extconf.rb; make|]
      pathogen_ (github "bling" "vim-airline")
      pathogen_ (github "stephpy" "vim-yaml")
      pathogen_ (github "roman" "golden-ratio")
    namespace "idris" $
      pathogen_ (github "idris-hackers" "idris-vim")
    namespace "rust" $
      pathogen_ (github "wting" "rust.vim")
    namespace "mine" $ do
      git (github "supki" "vim-flipping") (into "git") $
        register ".vim/bundle/vim-flipping"
      git (github "supki" "syntastic-cabal") (into "git") $
        register ".vim/bundle/syntastic-cabal"
      git (github "supki" "vim-languages") (into "git") $
        register ".vim/bundle/vim-languages"
      git' (github "supki" "seoul256.vim") (into ".vim/bundle") (branch "f/m")
      pathogen_ (github "supki" "haskell-vim")
  namespace "vimish" $
    namespace "haskell" $
      pathogen_ (github "bitc" "hdevtools")
 where
  pathogen  u = git u (into ".vim/bundle")
  pathogen_ u = pathogen u (return ())

emacs :: Script 'Sources ()
emacs = namespace "emacs" $ do
  namespace "colorschemes" $
    git (github "bbatsov" "zenburn-emacs") (into "git/emacs") $
      copy "zenburn-theme.el" ".emacs.d/themes/zenburn-theme.el"
  namespace "usable" $ do
    git (github "emacsmirror" "paredit") (into "git/emacs") $
      copy "paredit.el" ".emacs.d/plugins/paredit.el"
    git (github "jlr" "rainbow-delimiters") (into "git/emacs") $
      copy "rainbow-delimiters.el" ".emacs.d/plugins/rainbow-delimiters.el"

misc :: Script 'Sources ()
misc = namespace "misc" $ traverse_ (--> into "git")
  [ github "zsh-users" "zsh-syntax-highlighting"
  , github "zsh-users" "zsh-completions"
  , github "muennich" "urxvt-perls"
  ]

edwardk :: Script 'Sources ()
edwardk = namespace "edwardk" $ traverse_ (--> into "git") . map (github "ekmett") $
  [ "categories"
  , "discrimination"
  , "free"
  , "hyperfunctions"
  , "kan-extensions"
  , "lens"
  , "machines"
  , "profunctors"
  , "promises"
  , "reflection"
  , "tagged"
  ]

mine :: Script 'Sources ()
mine = namespace "mine" $
  traverse_ (--> into "git") . map (github "supki") $
    [ "xmonad-screenshot"
    , "xmonad-use-empty-workspace"
    , "xmonad-2014"
    , "pakej"
    ]

vimpager :: Script 'Sources ()
vimpager = namespace "vimpager" $
  git (github "rkitover" "vimpager") "git/vimpager" $ do
    [sh|PREFIX=$SOURCE_ROOT make install|]
    link "bin/vimpager" "bin/vless"
    link "bin/vimcat" "bin/vcat"

infix 8 -->
(-->) :: String -> FilePath -> Script 'Sources ()
(-->) = git_

dot :: FilePath -> (FilePath, FilePath)
dot path = path ~> ('.' : path)

bin :: FilePath -> (FilePath, FilePath)
bin path = path ~> combine "bin" path

unzipWithM_ :: Applicative m => (a -> b -> m c) -> [(a, b)] -> m ()
unzipWithM_ = traverse_ . uncurry

github :: String -> String -> String
github = printf "git@github.com:%s/%s"
