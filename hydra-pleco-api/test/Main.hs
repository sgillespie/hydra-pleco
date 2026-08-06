module Main (main) where

import Hydra.Pleco.ApiSpec qualified as ApiSpec

import Test.Hspec

main :: IO ()
main = hspec ApiSpec.spec
