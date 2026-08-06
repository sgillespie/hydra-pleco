module Hydra.Pleco.Cli
  ( Options (..),
    runCli,
    optionsParserInfo,
  ) where

import Hydra.Pleco.Api (projectName)

import Options.Applicative

{-# ANN Options ("HLint: ignore Use newtype instead of data" :: String) #-}
data Options = Options {optVerbose :: !Bool}
  deriving stock (Eq, Show)

runCli :: IO ()
runCli = execParser optionsParserInfo >>= run

run :: Options -> IO ()
run opts = putTextLn (projectName <> " cli: " <> show opts)

optionsParserInfo :: ParserInfo Options
optionsParserInfo =
  info (parser <**> helper) $
    fullDesc
      <> progDesc "The pleco command-line client for hydra-pleco"
      <> header "pleco - hydra-pleco command-line client"

parser :: Parser Options
parser = Options <$> verboseOpt
  where
    verboseOpt =
      switch $
        long "verbose"
          <> short 'v'
          <> help "Verbose output?"
