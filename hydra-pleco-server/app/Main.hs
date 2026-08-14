module Main (main) where

import Hydra.Pleco.Server (PlecoServerEnv (..), app)

import Network.Wai.Handler.Warp (run)

main :: IO ()
main = run 8081 (app env)
  where
    env = PlecoServerEnv
