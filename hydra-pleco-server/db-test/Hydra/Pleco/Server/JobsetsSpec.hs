module Hydra.Pleco.Server.JobsetsSpec (spec) where

import Hydra.Pleco.Api qualified as Api
import Hydra.Pleco.Client qualified as Client
import Hydra.Pleco.Server.TestApp qualified as TestApp

import Hasql.Pool (Pool)
import Network.HTTP.Types (status404)
import Test.Hspec (SpecWith, describe, it, shouldBe, shouldMatchList, shouldThrow)
import UnliftIO (try)

spec :: SpecWith (Text, Pool)
spec = describe "Hydra.Pleco.Server.Jobsets" $ do
  describe "jobsets" $ do
    describe "listJobsets" $ do
      it "lists every jobset for a project" $
        TestApp.withPlecoServer $ \port -> do
          jobsets <-
            TestApp.client port $
              Client.listJobsets (Api.ProjectId "pleco") Nothing
          map Api.jsId jobsets `shouldMatchList` map Api.JobsetId [1, 2]

      it "filters by jobset name" $
        TestApp.withPlecoServer $ \port -> do
          jobsets <-
            TestApp.client port $
              Client.listJobsets (Api.ProjectId "pleco") (Just (Api.JobsetName "main"))
          map Api.jsId jobsets `shouldMatchList` [Api.JobsetId 1]

      it "returns empty when filter does not match any jobset" $
        TestApp.withPlecoServer $ \port -> do
          jobsets <-
            TestApp.client port $
              Client.listJobsets
                (Api.ProjectId "pleco")
                (Just (Api.JobsetName "bogus-jobset"))
          map Api.jsId jobsets `shouldMatchList` []

      it "returns 404 when project does not exist" $
        TestApp.withPlecoServerCatching $ \port -> do
          -- Should throw 404 without jobset filter
          TestApp.client port (Client.listJobsets (Api.ProjectId "bogus-project") Nothing)
            `shouldThrow` TestApp.hasStatus status404

          -- And with a jobset filter
          let listJobsets' =
                Client.listJobsets
                  (Api.ProjectId "bogus-project")
                  (Just $ Api.JobsetName "main")
          TestApp.client port listJobsets' `shouldThrow` TestApp.hasStatus status404

      it "serves problem+json on project that does not exist" $
        TestApp.withPlecoServerCatching $ \port -> do
          -- Should return problem+json without jobset filter
          result <-
            try . TestApp.client port $
              Client.listJobsets (Api.ProjectId "bogus-project") Nothing
          TestApp.withProblemResponse result $ \problem ->
            Api.pdType problem `shouldBe` Api.problemTypeUri Api.NoSuchProject

          -- And with jobset filter
          result' <-
            try . TestApp.client port $
              Client.listJobsets
                (Api.ProjectId "bogus-project")
                (Just $ Api.JobsetName "main")
          TestApp.withProblemResponse result' $ \problem ->
            Api.pdType problem `shouldBe` Api.problemTypeUri Api.NoSuchProject

    describe "getJobset" $ do
      it "serves the expected jobset" $
        TestApp.withPlecoServer $ \port -> do
          jobset <- TestApp.client port $ Client.getJobset (Api.JobsetId 1)
          Api.jsId jobset `shouldBe` Api.JobsetId 1

      it "returns 404 when jobset does not exist" $
        TestApp.withPlecoServerCatching $ \port -> do
          TestApp.client port (Client.getJobset $ Api.JobsetId 999)
            `shouldThrow` TestApp.hasStatus status404

      it "serves problem+json on jobset that does not exist" $
        TestApp.withPlecoServerCatching $ \port -> do
          result <- try . TestApp.client port $ Client.getJobset (Api.JobsetId 999)
          TestApp.withProblemResponse result $ \problem ->
            Api.pdType problem `shouldBe` Api.problemTypeUri Api.NoSuchJobset
