module Hydra.Pleco.CliSpec (spec) where

import Hydra.Pleco.Cli (Options (..), optionsParserInfo)

import Options.Applicative (defaultPrefs, execParserPure, getParseResult)
import Test.Hspec

spec :: Spec
spec = describe "options parser" $ do
  it "defaults verbose to False" $
    parse [] `shouldBe` Just (Options False)

  it "parses --verbose" $
    parse ["--verbose"] `shouldBe` Just (Options True)
  where
    parse = getParseResult . execParserPure defaultPrefs optionsParserInfo
