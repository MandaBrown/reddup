{-# LANGUAGE OverloadedStrings #-}

module Handler where

import qualified GitParse as GP
import qualified Data.Text as T
import Prelude hiding (FilePath, concat)
import qualified Turtle as Tu
-- import qualified System.IO as SIO
import Data.Monoid ((<>))
import Trackable.Data
import Trackable.Util
import qualified System.IO as IO
import qualified ShellUtil
import qualified Config as C

inboxPrintHandler :: NHFile -> Tu.Shell ()
inboxPrintHandler (NHFile inbox file) =
  Tu.liftIO $ putStrLn $ T.unpack $ format
  where
    format =
      (pathToTextOrError inbox) <> ": file present " <> (pathToTextOrError file)

inboxInteractiveHandler :: NHFile -> C.ProcessedConfig -> Tu.Shell ()
inboxInteractiveHandler nh config = inboxHandler' nh config

inboxHandler' :: NHFile -> C.ProcessedConfig -> Tu.Shell ()
inboxHandler' nh@(NHFile inbox file) config = do
  let
    fmtMsg =
      (pathToTextOrError inbox) <> ": file present " <> (pathToTextOrError file)
  Tu.liftIO $ do
    putStrLn $ T.unpack $ fmtMsg
    putStrLn "Action choices:"
    putStrLn "(o)pen"
    putStrLn "(d)elete"
    putStrLn "open (e)nclosing directory"
    putStrLn "(r)ename file"
    putStrLn "open a (s)hell"
    putStrLn "(q)uit"
    putStr "Selection: "
    IO.hFlush IO.stdout
    selection <- getLine
    case selection of
      "o" -> do
        putStrLn "opening."
        Tu.sh $ do
          _ <- Tu.proc "open" [T.pack $ Tu.encodeString file] Tu.empty
          inboxHandler' nh config
      "d" -> do
        putStrLn "deleting."
        Tu.sh $ do
          Tu.rm file
      "e" -> do
        putStrLn "opening enclosing directory."
        Tu.sh $ do
          _ <- Tu.proc "open" [T.pack $ Tu.encodeString $ Tu.directory file] Tu.empty
          inboxHandler' nh config
      "s" -> do
        putStrLn "Starting bash. Reddup will continue when subshell exits."
        putStrLn "Filename available in shell as $FILE."
        let adtlVars = [("FILE", Tu.encodeString file)]
        ShellUtil.openInteractiveShell adtlVars
        Tu.sh $ do
          destinationExists <- Tu.testfile file
          if destinationExists then do
            Tu.liftIO $ putStrLn "file still exists, continuing processing"
            inboxHandler' nh config
          else
            Tu.liftIO $ putStrLn "file no longer exists, continuing to next file"
      "n" ->
        putStrLn "going to next."
        -- just return from this handler, nothing left to do
      "r" ->
        handleRename nh config
      "q" -> do
        Tu.sh $ Tu.exit Tu.ExitSuccess
      _ -> do



        putStrLn "input unrecognized."
        Tu.sh $ inboxHandler' nh config

handleRename :: NHFile -> C.ProcessedConfig -> IO ()
handleRename nh@(NHFile _inbox filePath) config = do
  putStrLn $ "renaming; original name " <> (T.unpack $ pathToTextOrError filePath)
  putStrLn $ "Enter new name:"
  IO.hFlush IO.stdout
  newName <- getLine
  let newPath = (Tu.directory filePath) Tu.</> (Tu.fromText $ T.pack newName)
  destinationExists <- Tu.testfile newPath
  if destinationExists then do
    putStrLn "destination exists; choose another name."
    handleRename nh config
  else do
    putStrLn $ "new name: " <> newName <>"; Is this OK?"
    putStrLn "(a)ccept new name"
    putStrLn "(c)ancel renaming (go back to previous menu)"
    putStrLn "(t)ry again (enter a new name)"
    IO.hFlush IO.stdout
    renameSelection <- getLine
    case renameSelection of
      "a" -> do
        Tu.sh $ Tu.mv filePath newPath
      "c" ->
        Tu.sh $ inboxHandler' nh config
      "t" ->
        handleRename nh config
      _ -> do
        putStrLn "input unrecognized."
        handleRename nh config

gitPrintHandler :: NHGit -> Tu.Shell ()
gitPrintHandler (NHGit dir' nhg) =
  Tu.liftIO $ putStrLn $ T.unpack $ format
  where
    format =
      let dir = pathToTextOrError dir' in
      case nhg of
        NHStatus (GP.Added f) -> formatPath dir f "file added"
        NHStatus (GP.AddedAndModified f) -> formatPath dir f "file added and modified"
        NHStatus (GP.Staged f) -> formatPath dir f "staged changes"
        NHStatus (GP.Unstaged f) -> formatPath dir f "unstaged changes"
        NHStatus (GP.StagedAndUnstaged f) -> formatPath dir f "staged and unstaged changes"
        NHStatus (GP.Untracked f) -> formatPath dir f "untracked file"
        NHStatus (GP.Deleted f) -> formatPath dir f "file deleted"
        NHStatus (GP.Unknown f) -> formatPath dir f "(unknown git status)"
        NHUnpushedBranch (GP.GitBranch branchName) ->
          dir <> ": Unpushed branch '" <> branchName <> "'"
        NHNotGitRepo -> dir <> ": is not a git repo"
    formatPath :: T.Text -> T.Text -> T.Text -> T.Text
    formatPath path statusItem label =
      path <> ": " <> label <> " '" <> statusItem  <> "'"