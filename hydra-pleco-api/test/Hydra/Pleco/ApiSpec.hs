module Hydra.Pleco.ApiSpec (spec) where

import Hydra.Pleco.Api (EventType (..))
import Hydra.Pleco.Api.Gen qualified as Gen

import Data.Aeson qualified as Aeson
import Data.OpenApi.Schema.Validation (validateToJSON)
import Hedgehog (forAll, (===))
import Test.Hspec
import Test.Hspec.Hedgehog (hedgehog, tripping)

spec :: Spec
spec = do
  describe "ProblemDetails" $ do
    it "round-trips through Aeson" $
      hedgehog $ do
        problem <- forAll Gen.problemDetails
        tripping problem Aeson.encode Aeson.eitherDecode

    it "toJSON and toEncoding matches" $ do
      hedgehog $ do
        problem <- forAll Gen.problemDetails
        Aeson.decode (Aeson.encode problem) === Just (Aeson.toJSON problem)

    it "conforms to OpenApi schema" $
      hedgehog $ do
        problem <- forAll Gen.problemDetails
        validateToJSON problem === []

  describe "Health" $ do
    it "round-trips through Aeson" $
      hedgehog $ do
        health <- forAll Gen.health
        tripping health Aeson.encode Aeson.eitherDecode

    it "toJSON and toEncoding matches" $
      hedgehog $ do
        health <- forAll Gen.health
        Aeson.decode (Aeson.encode health) === Just (Aeson.toJSON health)

    it "conforms to its OpenApi schema" $
      hedgehog $ do
        health <- forAll Gen.health
        validateToJSON health === []

  describe "Subscription" $ do
    it "round-trips through Aeson" $
      hedgehog $ do
        sub <- forAll Gen.subscription
        tripping sub Aeson.encode Aeson.eitherDecode

    it "toJSON and toEncoding matches" $
      hedgehog $ do
        sub <- forAll Gen.subscription
        Aeson.decode (Aeson.encode sub) === Just (Aeson.toJSON sub)

    it "conforms to its OpenApi schema" $
      hedgehog $ do
        sub <- forAll Gen.subscription
        validateToJSON sub === []

  describe "JobsetEvent" $ do
    it "round-trips through Aeson" $
      hedgehog $ do
        ev <- forAll Gen.jobsetEvent
        tripping ev Aeson.encode Aeson.eitherDecode

    it "toJSON and toEncoding matches" $
      hedgehog $ do
        ev <- forAll Gen.jobsetEvent
        Aeson.decode (Aeson.encode ev) === Just (Aeson.toJSON ev)

    it "conforms to its OpenApi schema" $
      hedgehog $ do
        ev <- forAll Gen.jobsetEvent
        validateToJSON ev === []

  describe "EventType" $ do
    let eventTypes =
          [ (EvalStarted, "eval_started"),
            (EvalAdded, "eval_added"),
            (EvalCached, "eval_cached"),
            (EvalFailed, "eval_failed"),
            (BuildQueued, "build_queued"),
            (CachedBuildQueued, "cached_build_queued"),
            (BuildStarted, "build_started"),
            (BuildFinished, "build_finished"),
            (CachedBuildFinished, "cached_build_finished")
          ]

    it "round-trips through Aeson" $
      hedgehog $ do
        ty <- forAll Gen.eventType
        tripping ty Aeson.encode Aeson.eitherDecode

    it "conforms to its OpenApi schema" $
      hedgehog $ do
        ty <- forAll Gen.eventType
        validateToJSON ty === []

    it "encodes all as Hydra event names" $
      for_ eventTypes $ \(ty, wire) -> do
        Aeson.toJSON ty `shouldBe` Aeson.String wire
        Aeson.eitherDecode (Aeson.encode wire) `shouldBe` Right ty

    it "names every constructor" $
      map fst eventTypes `shouldBe` universe

  describe "Project" $ do
    it "round-trips through Aeson" $
      hedgehog $ do
        prj <- forAll Gen.project
        tripping prj Aeson.encode Aeson.eitherDecode

    it "toJSON and toEncoding matches" $
      hedgehog $ do
        prj <- forAll Gen.project
        Aeson.decode (Aeson.encode prj) === Just (Aeson.toJSON prj)

    it "conforms to its OpenApi schema" $
      hedgehog $ do
        prj <- forAll Gen.project
        validateToJSON prj === []

  describe "ProjectId" $ do
    it "round-trips through Aeson" $
      hedgehog $ do
        id' <- forAll Gen.projectId
        tripping id' Aeson.encode Aeson.eitherDecode

    it "conforms to its OpenApi schema" $
      hedgehog $ do
        id' <- forAll Gen.projectId
        validateToJSON id' === []

  describe "Jobset" $ do
    it "round-trips through Aeson" $
      hedgehog $ do
        jobset <- forAll Gen.jobset
        tripping jobset Aeson.encode Aeson.eitherDecode

    it "toJSON and toEncoding matches" $
      hedgehog $ do
        jobset <- forAll Gen.jobset
        Aeson.decode (Aeson.encode jobset) === Just (Aeson.toJSON jobset)

    it "conforms to its OpenApi schema" $
      hedgehog $ do
        jobset <- forAll Gen.jobset
        validateToJSON jobset === []

  describe "JobsetId" $ do
    it "round-trips through Aeson" $
      hedgehog $ do
        id' <- forAll Gen.jobsetId
        tripping id' Aeson.encode Aeson.eitherDecode

    it "conforms to its OpenApi schema" $
      hedgehog $ do
        id' <- forAll Gen.jobsetId
        validateToJSON id' === []

  describe "JobsetName" $ do
    it "round-trips through Aeson" $
      hedgehog $ do
        name <- forAll Gen.jobsetName
        tripping name Aeson.encode Aeson.eitherDecode

    it "conforms to its OpenApi schema" $
      hedgehog $ do
        name <- forAll Gen.jobsetName
        validateToJSON name === []

  describe "JobsetState" $ do
    it "round-trips through Aeson" $
      hedgehog $ do
        st <- forAll Gen.jobsetState
        tripping st Aeson.encode Aeson.eitherDecode

    it "conforms to its OpenApi schema" $
      hedgehog $ do
        st <- forAll Gen.jobsetState
        validateToJSON st === []

  describe "JobsetType" $ do
    it "round-trips through Aeson" $
      hedgehog $ do
        jsType <- forAll Gen.jobsetType
        tripping jsType Aeson.encode Aeson.eitherDecode

    it "conforms to its OpenApi schema" $
      hedgehog $ do
        jsType <- forAll Gen.jobsetType
        validateToJSON jsType === []

  describe "Eval" $ do
    it "round-trips through Aeson" $
      hedgehog $ do
        ev <- forAll Gen.eval
        tripping ev Aeson.encode Aeson.eitherDecode

    it "toJSON and toEncoding matches" $
      hedgehog $ do
        ev <- forAll Gen.eval
        Aeson.decode (Aeson.encode ev) === Just (Aeson.toJSON ev)

    it "conforms to its OpenApi schema" $
      hedgehog $ do
        ev <- forAll Gen.eval
        validateToJSON ev === []

  describe "EvalId" $ do
    it "round-trips through Aeson" $
      hedgehog $ do
        id' <- forAll Gen.evalId
        tripping id' Aeson.encode Aeson.eitherDecode

    it "conforms to its OpenApi schema" $
      hedgehog $ do
        id' <- forAll Gen.evalId
        validateToJSON id' === []
