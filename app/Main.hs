{-# LANGUAGE OverloadedStrings #-}

module Main where

import Data.Text hiding (empty)
import Prelude hiding (FilePath, concat)
import Turtle
import Git
import GitParse
import qualified Config
import qualified ShellUtil

data Trackable
  = GitRepo Turtle.FilePath
  | InboxDir Turtle.FilePath
  deriving (Show)

directoriesConfig :: Shell Trackable
directoriesConfig = do
  let
    gitRepos = [ "~/EF"
               , "~/Reference"
               , "~/Projects/*"
               , "~/ttm/apangea"
               ]
    inboxDirs = [ "~/Inbox",
                  "~/Desktop"
                ]
    in do
      gitDirectoriesConfig gitRepos
        <|> inboxDirectoriesConfig inboxDirs

gitDirectoriesConfig :: [Text] -> Shell Trackable
gitDirectoriesConfig dirs = do
  repoDir <- select dirs
  path <- ShellUtil.expandGlob repoDir
  return $ (GitRepo . fromText . lineToText $ path)

inboxDirectoriesConfig :: [Text] -> Shell Trackable
inboxDirectoriesConfig dirs = do
  repoDir <- select dirs
  path <- ShellUtil.expandGlob repoDir
  return $ (InboxDir . fromText . lineToText $ path)

handleTrackable :: Trackable -> Shell ()
handleTrackable (GitRepo dir) = do
  liftIO $ putStrLn $ "checking " ++ show dir
  cd dir
  dirExists <- testdir ".git"
  if dirExists then
    liftIO checkGitStatus
  else
    liftIO $ putStrLn $ "ERROR IS NOT GIT REPO"
  return ()

handleTrackable (InboxDir dir) = do
  liftIO $ putStrLn $ "checking " ++ show dir
  cd dir
  let status = ls "."
  view status
  return ()

checkGitStatus :: IO ()
checkGitStatus = do
  let status = gitStatus
  view status
  let unpushedBranches = unpushedGitBranches
  stdout $ fmap unsafeTextToLine $ fmap viewGitBranchAsUnpushed unpushedBranches

viewGitBranchAsUnpushed :: GitBranchType -> Text
viewGitBranchAsUnpushed (GitBranch name) =
  Data.Text.append "Unpushed: " name

main :: IO ()
main = sh $ do
  config <- liftIO Config.loadConfig
  -- trackable <- directoriesConfig
  -- handleTrackable trackable
