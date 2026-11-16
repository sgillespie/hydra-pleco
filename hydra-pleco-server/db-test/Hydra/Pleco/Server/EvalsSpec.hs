module Hydra.Pleco.Server.EvalsSpec (spec) where

import Hydra.Pleco.Api qualified as Api
import Hydra.Pleco.Client qualified as Client
import Hydra.Pleco.Server.TestApp as TestApp

import Hasql.Pool (Pool)
import Network.HTTP.Types (status404)
import Test.Hspec (SpecWith, describe, it, shouldBe, shouldMatchList, shouldThrow)
import UnliftIO (try)

spec :: SpecWith (Text, Pool)
spec = describe "Hydra.Pleco.Server.Evals" $ do
  describe "evals" $ do
    describe "listEvals" $ do
      it "lists every eval for a jobset" $ do
        TestApp.withPlecoServer $ \port -> do
          evals <- TestApp.client port $ Client.listEvals (Api.JobsetId 1)
          map Api.evId evals `shouldMatchList` [Api.EvalId 1, Api.EvalId 2]

      it "returns 404 when jobset does not exist" $
        TestApp.withPlecoServerCatching $ \port ->
          TestApp.client port (Client.listEvals $ Api.JobsetId 999)
            `shouldThrow` TestApp.hasStatus status404

      it "serves problem+json when jobset does not exist" $
        TestApp.withPlecoServerCatching $ \port -> do
          result <- try . TestApp.client port $ Client.listEvals (Api.JobsetId 999)
          TestApp.withProblemResponse result $ \problem ->
            Api.pdType problem `shouldBe` Api.problemTypeUri Api.NoSuchJobset

    describe "findEvals" $ do
      it "lists every eval for a jobset" $ do
        TestApp.withPlecoServer $ \port -> do
          evals <-
            TestApp.client port $
              Client.findEvals (Client.JobsetSpec (Api.ProjectId "pleco") (Api.JobsetName "main"))
          map Api.evId evals `shouldMatchList` [Api.EvalId 1]

      it "returns 404 when project does not exist" $
        TestApp.withPlecoServerCatching $ \port ->
          let findEvals' =
                Client.findEvals $
                  Client.JobsetSpec (Api.ProjectId "bogus-project") (Api.JobsetName "main")
          in  TestApp.client port findEvals' `shouldThrow` TestApp.hasStatus status404

      it "serves problem+json when project does not exist" $
        TestApp.withPlecoServerCatching $ \port -> do
          result <-
            try . TestApp.client port $
              Client.findEvals $
                Client.JobsetSpec (Api.ProjectId "bogus-project") (Api.JobsetName "main")

          TestApp.withProblemResponse result $ \problem ->
            Api.pdType problem `shouldBe` Api.problemTypeUri Api.NoSuchProject

    describe "getEval" $ do
      it "serves the expected eval" $
        TestApp.withPlecoServer $ \port -> do
          eval <- TestApp.client port (Client.getEval $ Api.EvalId 1)
          Api.evId eval `shouldBe` Api.EvalId 1

      it "returns 404 when eval does not exist" $
        TestApp.withPlecoServerCatching $ \port -> do
          TestApp.client port (Client.getEval $ Api.EvalId 999) `shouldThrow` TestApp.hasStatus status404

      it "serves problem+json when eval does not exist" $
        TestApp.withPlecoServerCatching $ \port -> do
          result <- try . TestApp.client port $ Client.getEval (Api.EvalId 999)
          TestApp.withProblemResponse result $ \problem ->
            Api.pdType problem `shouldBe` Api.problemTypeUri Api.NoSuchEval
