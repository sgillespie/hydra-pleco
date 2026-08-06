module Hydra.Pleco.ApiSpec (spec) where

import Hydra.Pleco.Api (projectName)

import Test.Hspec

spec :: Spec
spec =
  describe "projectName" $
    it "is hydra-pleco" $
      projectName `shouldBe` "hydra-pleco"
