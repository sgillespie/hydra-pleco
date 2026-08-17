module Hydra.Pleco.ApiSpec (spec) where

import Hydra.Pleco.Api.Gen qualified as Gen

import Data.Aeson qualified as Aeson
import Hedgehog (forAll)
import Test.Hspec
import Test.Hspec.Hedgehog (hedgehog, tripping)

spec :: Spec
spec = do
  describe "Health" $
    it "round-trips through Aeson" $
      hedgehog $ do
        health <- forAll Gen.health
        tripping health Aeson.encode Aeson.decode

  describe "Subscription" $
    it "round-trips through Aeson" $
      hedgehog $ do
        sub <- forAll Gen.subscription
        tripping sub Aeson.encode Aeson.decode

  describe "JobsetEvent" $
    it "round-trips through Aeson" $
      hedgehog $ do
        ev <- forAll Gen.jobsetEvent
        tripping ev Aeson.encode Aeson.decode

  describe "EventType" $
    it "round-trips through Aeson" $
      hedgehog $ do
        ty <- forAll Gen.eventType
        tripping ty Aeson.encode Aeson.decode
