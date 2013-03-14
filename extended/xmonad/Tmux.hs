{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE ViewPatterns #-}
-- | Semi-usable tmux sessions prompt for XMonad
--
-- Inspired by Simon Gomizelj (@vodik) - https://github.com/vodik/dotfiles/blob/master/xmonad/lib/XMonad/Util/Tmux.hs
module Tmux where

import Control.Applicative
import Control.Monad
import Data.List (nub, sort)
import Data.Monoid

import           Data.Map (Map, (!))
import qualified Data.Map as M
import           System.FilePath (takeFileName)
import           System.Directory (doesDirectoryExist)
import           System.Wordexp.Simple (wordexp)

import XMonad hiding (S)
import XMonad.Prompt
import XMonad.Prompt.Input
import XMonad.Util.Run


-- | Less typing type synonym
type Sessions = Map String Command

-- | Possible startup commands for tmux sessions
data Command =
    ChangeDirectory FilePath -- ^ Change directory before starting session
  | Session String           -- ^ Start session for specific command
    deriving (Show, Read, Eq, Ord)

-- | Newtype 'String' that discards first '*' (if any) in 'Eq' instance
newtype S = S { unS :: String }
  deriving (Show, Read)

instance Eq S where
  S ('*' : a) == S ('*' : b) = a == b
  S        a  == S ('*' : b) = a == b
  S ('*' : a) == S        b  = a == b
  S        a  == S        b  = a == b


un :: String -> String
un ('*' : s) = s
un        s  = s


-- | Get current active tmux sessions names
currents :: X [String]
currents = io $ lines <$> runProcessWithInput "tmux" ["list-sessions", "-F", "#{session_name}"] ""


-- | Ask what session user wants to create/attach to
prompt :: Sessions   -- ^ Default user defined sessions
       -> [String]   -- ^ Patterns for ChangeDirectory sessions
       -> XPConfig   -- ^ Prompt theme
       -> X ()
prompt db ps c = do
  cs <- currents
  ss <- change =<< concatMapM expand ps
  let as = sort . map unS . nub . map S $ map ('*' :) cs ++ M.keys (ss `mappend` db)
  inputPromptWithCompl c "tmux" (mkComplFunFromList' as) ?+ start (ss `mappend` db) cs


-- | That should exist in Control.Monad :-(
concatMapM :: Monad m => (a -> m [b]) -> [a] -> m [b]
concatMapM f = liftM concat . mapM f
{-# INLINE concatMapM #-}


-- | Safely expands wordexp pattern catching IO errors
expand :: String -> X [FilePath]
expand p = io $ wordexp p `mplus` return []


-- | List directories as ChangeDirectory sessions
change :: [FilePath] -- ^ Directories
       -> X Sessions -- ^ Sessions for each directory under the root
change ds = io $
  M.fromList . map (\x -> (takeFileName x, ChangeDirectory x)) <$> filterM doesDirectoryExist ds


-- | Start tmux session terminal
-- May either start a new tmux session if it does not exist or connect to existing session
start :: Sessions -> [String] -> String -> X ()
start as ss (un -> s) = do
  term <- asks $ terminal . config
  spawn $ case undefined of
    _ | s `elem` ss     -> attach  term s
      | s `M.member` as -> create' term s (as ! s)
      | otherwise       -> create  term s
 where
  attach t s = t ++ " -e tmux attach -t " ++ s
  create t s = t ++ " -e tmux new -s "    ++ s
  create' t s (ChangeDirectory p) =
    t ++ " -e sh -c \"cd " ++ p ++ "; tmux new -s "    ++ s ++ "\""
  create' t s (Session c) =
    t ++ " -e tmux new -s "    ++ s ++ " '" ++ c ++ "'"
