{-# LANGUAGE OverloadedStrings #-}

module Trackable where

import qualified Data.Text as T
import Prelude hiding (FilePath, concat)
import qualified Turtle as Tu
import qualified Git as Git
import qualified System.IO as SIO
import Data.Monoid ((<>))
import qualified GitParse as GP
import qualified ShellUtil
import qualified Config as C
import qualified Options as O

data Trackable
  = GitRepo  Tu.FilePath
  | InboxDir Tu.FilePath
  | UnknownTrackable T.Text Tu.FilePath
  deriving (Show)

data NeedsHandled
  = NHGit Trackable NHGit
  | NHFile Trackable Tu.FilePath

data NHGit
  = NHStatus GP.GitStatus
  | NHUnpushedBranch GP.GitBranch
  | NHNotGitRepo

printHandler :: NeedsHandled -> Tu.Shell ()
printHandler nh =
  Tu.liftIO $ putStrLn $ T.unpack $ format
  where
    format =
      case nh of
        NHGit trackable nhg ->
          let (GitRepo dir') = trackable
              dir = pathToTextOrError dir'
          in
          case nhg of
            NHStatus (GP.Staged f) -> formatPath dir f "staged changes"
            NHStatus (GP.Unstaged f) -> formatPath dir f "unstaged changes"
            NHStatus (GP.Untracked f) -> formatPath dir f "untracked file"
            NHStatus (GP.Unknown f) -> formatPath dir f "(unknown git status)"
            NHUnpushedBranch (GP.GitBranch branchName) ->
              dir <> ": Unpushed branch '" <> branchName <> "'"
            NHNotGitRepo -> dir <> ": Not a git repo"
        _ -> undefined

    formatPath :: T.Text -> T.Text -> T.Text -> T.Text
    formatPath path statusItem label =
      path <> ": " <> label <> " '" <> statusItem  <> "'"

handleTrackables :: Tu.Shell Trackable -> O.Options -> Tu.Shell ()
handleTrackables trackables opts =
  trackables >>= handleTrackable opts

handleTrackable :: O.Options -> Trackable -> Tu.Shell ()
handleTrackable opts trackable =
  case trackable of
    (GitRepo _) ->
      handleGitTrackable opts trackable
    (InboxDir dir) ->
      handleInboxTrackable opts dir
    (UnknownTrackable type' dir) ->
      handleUnknownTrackable opts type' dir

handleGitTrackable :: O.Options -> Trackable -> Tu.Shell ()
handleGitTrackable opts trackable = do
  let (GitRepo dir) = trackable
  O.verbose opts $ "checking " <> (T.pack $ show dir)
  Tu.cd dir
  dirExists <- Tu.testdir ".git"
  if dirExists then
    Tu.liftIO $ checkGitStatus trackable
  else
    Tu.liftIO $ SIO.putStrLn $ "Warning: " <> (T.unpack $ pathToTextOrError dir) <> " IS NOT A GIT REPO"
  return ()

handleUnknownTrackable :: O.Options -> T.Text -> Tu.FilePath -> Tu.Shell ()
handleUnknownTrackable  _ type' dir =
  Tu.liftIO $ print $ ("warning: encountered unknown trackable definition " Tu.<> type' Tu.<> " at " Tu.<> (T.pack (show dir)))

handleInboxTrackable :: O.Options -> Tu.FilePath -> Tu.Shell ()
handleInboxTrackable opts dir = do
  O.verbose opts $ "checking " <> pathToTextOrError dir
  Tu.cd dir
  let status = Tu.ls "."
  Tu.sh (status >>= Tu.liftIO . putStrLn . T.unpack . ((formatInboxTrackable dir) . Tu.filename))
  return ()

formatInboxTrackable :: Tu.FilePath -> Tu.FilePath -> T.Text
formatInboxTrackable dir item =
  (pathToTextOrError dir) <> "/" <> (pathToTextOrError item) <> ": file present"

checkGitStatus :: Trackable  -> IO ()
checkGitStatus trackable = do
  let gitUnhandled =
        (wrapStatus Git.gitStatus) Tu.<|>
        (wrapUnpushed Git.unpushedGitBranches)
  Tu.sh $ gitUnhandled >>= printHandler
  where
    wrapStatus   = (NHGit trackable <$> NHStatus <$>)
    wrapUnpushed = (NHGit trackable <$> NHUnpushedBranch <$>)

pathToTextOrError ::  Tu.FilePath -> T.Text
pathToTextOrError path =
  case (Tu.toText path) of
    Left l ->
      "(Decode ERROR: problem with path encoding for " <> l <> ")"
    Right r -> r

configToTrackables :: C.Config -> Tu.Shell Trackable
configToTrackables (C.Config { C.locations = locations }) = do
  location <- Tu.select locations
  locationSpecToTrackable location

locationSpecToTrackable :: C.LocationSpec -> Tu.Shell Trackable
locationSpecToTrackable (C.LocationSpec { C._type = _type,  C.location = location }) = do
  let allExpanded = fmap (Tu.fromText . Tu.lineToText) (ShellUtil.expandGlob location)
  _path <- allExpanded
  let trackable =
        case _type of
          "git"   -> GitRepo _path
          "inbox" -> InboxDir _path
          _       -> UnknownTrackable _type  _path
  return trackable
