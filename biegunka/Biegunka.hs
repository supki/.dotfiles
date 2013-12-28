{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE TemplateHaskell #-}
{-# OPTIONS_GHC -Wall #-}
{-# OPTIONS_GHC -fno-warn-missing-signatures #-}
module Main (main) where

import           Control.Applicative
import           Control.Lens
import           Data.Default (def)
import           Data.Foldable (traverse_)
import           System.FilePath ((</>))

import           Control.Biegunka
import           Control.Biegunka.Source.Git
import           Control.Biegunka.Templates.HStringTemplate

import qualified Laptop
import qualified Work


data Environments = Laptop | Work

biegunkaOptions ''Environments


main :: IO ()
main = do
  (environment, runBiegunka) <- options
  let settings ts = set root "~" . set templates (hStringTemplate ts)
  case environment of
    Laptop -> runBiegunka (settings Laptop.templates) laptop
    Work   -> runBiegunka (settings Work.templates) work
 where
  laptop = sudo "maksenov" $ sequence_
    [ dotfiles
    , tools
    , vim
    , emacs
    , misc
    , experimental
    , edwardk
    , mine
    ]
  work = sequence_
    [ dotfiles
    , vim
    , misc
    , experimental
    ]


dotfiles = role "dotfiles" $
  git "git@github.com:supki/.dotfiles" "git/dotfiles" $ do
    cores     & mapped._1 <\>~ "core"     & unzipWithM_ link
    extendeds & mapped._1 <\>~ "extended" & unzipWithM_ link
    recipes   & mapped._1 <\>~ "extended" & unzipWithM_ substitute
    miscs     & mapped._1 <\>~ "misc"     & unzipWithM_ link
    [sh|xrdb -merge ~/.Xdefaults|]
    [sh|xmonad --recompile|]
    [sh|pakej --recompile|]
    let pathogen_url :: String
        pathogen_url = "https://raw.github.com/tpope/vim-pathogen/master/autoload/pathogen.vim"
    [sh|
      mkdir -p  ~/.vim/autoload ~/.vim/bundle ~/.vim/colors
      curl -o ~/.vim/autoload/pathogen.vim #{pathogen_url}
    |]
 where
  cores =
    [ dot "xsession"
    , dot "mpdconf"
    , dot "profile"
    , dot "bashrc"
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
    , dot "guardrc"
    , dot "guard.rb"
    , "vim/vim.custom"             ~> ".vim/plugin/vimrc-local.vim"
    , "vim/indent/haskell.vim"     ~> ".vim/indent/haskell.vim"
    , "vim/camo.vim"               ~> ".vim/colors/camo.vim"
    , "vim/zenburn.vim"            ~> ".vim/colors/zenburn.vim"
    , "vim/conceal/haskell.vim"    ~> ".vim/after/syntax/haskell.vim"
    , "pakej.hs"                   ~> ".pakej/pakej.hs"
    ]
  extendeds =
    [ dot "gvimrc"
    , dot "pentadactylrc"
    , dot "gtkrc.mine"
    , "xmonad.hs"                  ~> ".xmonad/xmonad.hs"
    , "xmonad/Bindings.hs"         ~> ".xmonad/lib/Bindings.hs"
    , "xmonad/Layouts.hs"          ~> ".xmonad/lib/Layouts.hs"
    , "xmonad/Startup.hs"          ~> ".xmonad/lib/Startup.hs"
    , "xmonad/Themes.hs"           ~> ".xmonad/lib/Themes.hs"
    , "xmonad/RouteT.hs"           ~> ".xmonad/lib/RouteT.hs"
    , "xmonad/Tmux.hs"             ~> ".xmonad/lib/Tmux.hs"
    , "xmonad/Man.hs"              ~> ".xmonad/lib/Man.hs"
    , "xmonad/Workspaces.hs"       ~> ".xmonad/lib/Workspaces.hs"
    , "xmonad/Spawn.hs"            ~> ".xmonad/lib/Spawn.hs"
    , "pentadactyl/wanker.penta"   ~> ".pentadactyl/plugins/wanker.penta"
    , "mplayer-config"             ~> ".mplayer/config"
    ]
  recipes =
    [ "template.xmobar.hs"         ~> ".xmobar/xmobar.hs"
    , "xmonad/Profile.hs.template" ~> ".xmonad/lib/Profile.hs"
    , "xmodmap.template"           ~> ".xmodmap"
    , "Xdefaults.template"         ~> ".Xdefaults"
    ]
  miscs =
    [ bin "bat.rb"
    , bin "cpu.pl"
    , bin "date.sh"
    , bin "ip.awk"
    , bin "loadavg.awk"
    , bin "mem.awk"
    , bin "weather.rb"
    ]

tools = role "tools" $
  git "git@budueba.com:tools" "git/tools" $ do
    suid_binaries & unzipWithM_ (\s t ->
      sudo "root" $ [sh|
        ghc -O2 #{s} -fforce-recomp -threaded -v0 -o #{t}
        chown root:root #{t}
        chmod +s #{t}
      |])
    user_binaries & unzipWithM_ (\s t -> do
      [sh|ghc -O2 #{s} -fforce-recomp -v0 -o #{t}|]
      link t ("bin" </> t))
    scripts & unzipWithM_ link
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


vim = do
  role "vim" $ do
    group "haskell" $ do
      pathogen  "git@github.com:Shougo/vimproc" $
        [sh|make -f make_unix.mak|]
      pathogen_ "git@github.com:eagletmt/ghcmod-vim"
      pathogen_ "git@github.com:eagletmt/unite-haddock"
      pathogen_ "git@github.com:ujihisa/neco-ghc"
      pathogen_ "git@github.com:Shougo/neocomplcache"
      pathogen_ "git@github.com:bitc/vim-hdevtools"
      pathogen_ "git@github.com:merijn/haskellFoldIndent"
      pathogen_ "git@github.com:supki/syntastic-cabal"
    group "ruby" $ do
      pathogen_ "git@github.com:kana/vim-textobj-user"
      pathogen_ "git@github.com:nelstrom/vim-textobj-rubyblock"
    group "coq" $ do
      pathogen_ "git@github.com:vim-scripts/coq-syntax"
      pathogen_ "git@github.com:vim-scripts/Coq-indent"
      pathogen_ "git@github.com:trefis/coquille"
    group "misc" $ do
      pathogen_ "git@github.com:wikitopian/hardmode"
      pathogen_ "git@github.com:scrooloose/syntastic"
      pathogen_ "git@github.com:Shougo/unite.vim"
      pathogen_ "git@github.com:spolu/dwm.vim"
      pathogen_ "git@github.com:tpope/vim-commentary"
      pathogen_ "git@github.com:tpope/vim-unimpaired"
      pathogen_ "git@github.com:def-lkb/vimbufsync"
      pathogen_ "git@github.com:junegunn/seoul256.vim"
      pathogen_ "git@github.com:ivyl/vim-bling"
      pathogen_ "git@github.com:Glench/Vim-Jinja2-Syntax"
    group "agda" $
      pathogen_ "git@github.com:supki/agda-vim"
    group "idris" $
      "git@github.com:edwinb/Idris-dev" ==> into "git" $ def
        & remotes .~ ["origin", "stream"]
        & actions .~
            link "contribs/tool-support/vim" ".vim/bundle/idris-vim"
    group "text" $
      pathogen_ "git@github.com:godlygeek/tabular"
  role "vimish" $
    group "haskell" $
      pathogen_ "git@github.com:bitc/hdevtools"
 where
  pathogen  u = git u (into ".vim/bundle")
  pathogen_ u = pathogen u (return ())


emacs = role "emacs" $ do
  group "colorschemes" $
    git "git@github.com:bbatsov/zenburn-emacs" (into "git/emacs") $
      copyFile "zenburn-theme.el" ".emacs.d/themes/zenburn-theme.el"
  group "usable" $ do
    git "git@github.com:emacsmirror/paredit" (into "git/emacs") $
      copyFile "paredit.el" ".emacs.d/plugins/paredit.el"
    git "git@github.com:jlr/rainbow-delimiters" (into "git/emacs") $
      copyFile "rainbow-delimiters.el" ".emacs.d/plugins/rainbow-delimiters.el"


misc = role "misc" $ traverse_ (--> into "git")
  [ "git@github.com:zsh-users/zsh-syntax-highlighting"
  , "git@github.com:zsh-users/zsh-completions"
  , "git@github.com:stepb/urxvt-tabbedex"
  , "git@github.com:muennich/urxvt-perls"
  ]


experimental = role "experimental" $ traverse_ (--> into "git")
  [ "git@github.com:sol/vimus"
  , "git@github.com:sol/libmpd-haskell"
  , "git@github.com:mitchellh/vagrant"
  ]


edwardk = role "edwardk" $ traverse_ (--> into "git")
  [ "git@github.com:ekmett/free"
  , "git@github.com:ekmett/reflection"
  , "git@github.com:ekmett/tagged"
  , "git@github.com:ekmett/machines"
  , "git@github.com:ekmett/lens"
  , "git@github.com:ekmett/profunctors"
  , "git@github.com:ekmett/kan-extensions"
  ]

mine = role "mine" $ traverse_ (--> into "git")
  [ "git@github.com:supki/libjenkins"
  ]


infix 8 -->
(-->) :: String -> FilePath -> Script Sources ()
(-->) = git_

dot :: FilePath -> (FilePath, FilePath)
dot path = path ~> ('.' : path)

bin :: FilePath -> (FilePath, FilePath)
bin path = path ~> ("bin" </> path)

infixr 4 <\>~
(<\>~) :: Setting (->) s t FilePath FilePath -> FilePath -> s -> t
l <\>~ n = over l (n </>)


unzipWithM_ :: Applicative m => (a -> b -> m c) -> [(a, b)] -> m ()
unzipWithM_ = traverse_ . uncurry
