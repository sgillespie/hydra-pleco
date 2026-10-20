module Main (main) where

import Hydra.Pleco.CliSpec qualified as CliSpec
import Hydra.Pleco.Client.FormattingSpec qualified as FormattingSpec

import Test.Hspec

main :: IO ()
main = hspec $ do
  CliSpec.spec
  FormattingSpec.spec
