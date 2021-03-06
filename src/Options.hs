{-# LANGUAGE OverloadedStrings #-}

module Options where

import qualified Data.Text as T
import Prelude hiding (FilePath, concat)
import qualified Turtle as Tu
import qualified System.IO as SIO

data Options = Options
  { _debug :: Bool
  , _verbose :: Bool
  , _interactive :: Bool
  }
  deriving (Eq, Show)

parser :: Tu.Parser Options
parser =
  Options <$>
    Tu.switch "debug" 'd' "Print debug information to stderr" <*>
    Tu.switch "verbose" 'v' "Print verbose information to stdout" <*>
    Tu.switch "interactive" 'i' "Handle found items interactively"


parseOpts :: Tu.Shell Options
parseOpts = Tu.options "Reddup: Keep your computer tidy" parser
