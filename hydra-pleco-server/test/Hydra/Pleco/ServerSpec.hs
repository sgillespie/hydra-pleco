module Hydra.Pleco.ServerSpec (spec) where

import Hydra.Pleco.Server (PlecoServerEnv (..), runPlecoServerT)

import Test.Hspec

spec :: Spec
spec = describe "runPlecoServerT" $
  it "runs an action in the reader environment" $ do
    env <- runPlecoServerT PlecoServerEnv ask
    env `shouldBe` PlecoServerEnv
