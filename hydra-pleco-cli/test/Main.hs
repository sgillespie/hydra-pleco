module Main (main) where

import Hydra.Pleco.CliSpec qualified as CliSpec

import Test.Hspec

main :: IO ()
main = hspec CliSpec.spec
