module Trackable.Data where

import qualified Turtle as Tu
import qualified GitParse as GP
import Prelude hiding (FilePath)


type GitRepoPath = Tu.FilePath
type InboxPath = Tu.FilePath
type FilePath = Tu.FilePath

data Trackable
  = GitRepo GitRepoPath
  | InboxDir InboxPath
  deriving (Show)

data NHGit = NHGit GitRepoPath NHGitItem
data NHFile = NHFile InboxPath FilePath

data NHGitItem
  = NHStatus GP.GitStatus
  | NHUnpushedBranch GP.GitBranch
  | NHNotGitRepo
