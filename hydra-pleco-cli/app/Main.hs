module Main (main) where

import Control.Exception (throwIO)
import Hydra.Pleco.Client (BaseUrl (..), Scheme (..), defaultManagerSettings, getHealth, mkPlecoClientEnv, newManager, runPlecoClient)
import Options.Applicative (Parser, ParserInfo)
import Options.Applicative qualified as Opt

-- TODO[sgillespie]: Remove me!
{-# ANN module ("HLint: ignore Use newtype instead of data" :: String) #-}

data Options = Options
  { optVerbose :: !Bool
  }
  deriving stock (Eq, Show)

main :: IO ()
main = Opt.execParser parserInfo >>= run

parserInfo :: ParserInfo Options
parserInfo =
  Opt.info (parser <**> Opt.helper) $
    Opt.fullDesc
      <> Opt.progDesc "Command line cliend for hydra-pleco API"
      <> Opt.header "hydra-pleco command-line client"

run :: Options -> IO ()
run _ = do
  manager' <- newManager defaultManagerSettings
  let env = mkPlecoClientEnv manager' (BaseUrl Http "localhost" 8081 "")
  res <- runPlecoClient env getHealth
  either throwIO print res

parser :: Parser Options
parser =
  Options
    <$> parseVerbose

parseVerbose :: Parser Bool
parseVerbose =
  Opt.switch $
    Opt.long "verbose"
      <> Opt.short 'v'
      <> Opt.help "Verbose output?"
