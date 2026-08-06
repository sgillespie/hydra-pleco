module Main (main) where

import Hydra.Pleco.AppSpec qualified as AppSpec

import Test.Hspec

main :: IO ()
main = hspec AppSpec.spec
