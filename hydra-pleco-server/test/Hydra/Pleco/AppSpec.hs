module Hydra.Pleco.AppSpec (spec) where

import Hydra.Pleco.App (Env (..), runApp)

import Test.Hspec

spec :: Spec
spec = describe "runApp" $
  it "runs an action in the reader environment" $ do
    env <- runApp ask Env
    env `shouldBe` Env
