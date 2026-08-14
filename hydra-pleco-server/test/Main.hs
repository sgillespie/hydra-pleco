module Main (main) where

import Hydra.Pleco.ServerSpec qualified as ServerSpec

import Test.Hspec

main :: IO ()
main = hspec ServerSpec.spec
