module Main (main) where

import Hydra.Pleco.Api (projectName)
import Hydra.Pleco.App (App, Env (..), runApp)

main :: IO ()
main = runApp run Env

run :: App ()
run = putTextLn (projectName <> " server (skeleton)")
