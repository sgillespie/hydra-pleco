module Main (main) where

import Hydra.Pleco.Server (PlecoServerEnv (..), app, mkPlecoServerEnv, runApp)

import Network.Wai.Handler.Warp (run)

main :: IO ()
main = do
  env <- mkPlecoServerEnv
  runApp 8081 env
