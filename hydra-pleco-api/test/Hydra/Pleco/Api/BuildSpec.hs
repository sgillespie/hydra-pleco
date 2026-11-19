module Hydra.Pleco.Api.BuildSpec (spec) where

import qualified Hydra.Pleco.Api.Gen as Gen

import Data.Aeson qualified as Aeson
import Data.OpenApi.Schema.Validation (validateToJSON)
import Hedgehog (forAll, (===))
import Test.Hspec (Spec, describe, it)
import Test.Hspec.Hedgehog (hedgehog, tripping)

spec :: Spec
spec = 
  describe "Hydra.Pleco.Api.Build" $ do
    describe "Build" $ do
      it "round-trips through Aeson" $
        hedgehog $ do
          build <- forAll Gen.build
          tripping build Aeson.encode Aeson.eitherDecode

      it "toJSON and toEncoding matches" $ 
        hedgehog $ do
          build <- forAll Gen.build
          Aeson.decode (Aeson.encode build) === Just (Aeson.toJSON build)

      it "conforms to its OpenApi schema" $
        hedgehog $ do
          build <- forAll Gen.build
          validateToJSON build === []

    describe "BuildStatus" $ do
      it "round-trips through Aeson" $
        hedgehog $ do
          build <- forAll Gen.buildStatus
          tripping build Aeson.encode Aeson.eitherDecode

      it "toJSON and toEncoding matches" $ 
        hedgehog $ do
          build <- forAll Gen.buildStatus
          Aeson.decode (Aeson.encode build) === Just (Aeson.toJSON build)

      it "conforms to its OpenApi schema" $
        hedgehog $ do
          build <- forAll Gen.buildStatus
          validateToJSON build === []
