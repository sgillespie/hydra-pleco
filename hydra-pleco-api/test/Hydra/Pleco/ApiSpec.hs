module Hydra.Pleco.ApiSpec (spec) where

import Hydra.Pleco.Api ()

import Test.Hspec

spec :: Spec
spec =
  describe "projectName" $
    it "is hydra-pleco" $
      "hydra-pleco" `shouldBe` "hydra-pleco"
