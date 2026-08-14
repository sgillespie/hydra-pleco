module Hydra.Pleco.ServerSpec (spec) where

import Hydra.Pleco.Server (PlecoServerEnv (..), mkPlecoServerEnv, runPlecoServerT)

import Test.Hspec

spec :: Spec
spec = describe "runPlecoServerT" $
  it "runs an action in the reader environment" $ do
    env <- mkPlecoServerEnv
    ns <- runPlecoServerT env (asks pseLogNamespace)
    pseLogNamespace env `shouldBe` ns
