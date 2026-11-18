module Hydra.Pleco.Server.Handlers.ProjectsSpec (spec) where

import Hydra.Pleco.Api qualified as Api
import Hydra.Pleco.Client qualified as Client
import Hydra.Pleco.Server.TestApp qualified as TestApp

import Hasql.Pool (Pool)
import Network.HTTP.Types.Status (status404)
import Test.Hspec
import UnliftIO (try)

spec :: SpecWith (Text, Pool)
spec = describe "Hydra.Pleco.Server.Handlers.Projects" $ do
  describe "projects" $ do
    describe "listProjects" $ do
      it "lists every project" $
        TestApp.withPlecoServer $ \port -> do
          let expectedProjects = ["pleco", "hidden", "paused"]

          projects <- TestApp.client port Client.listProjects
          map Api.prjId projects `shouldMatchList` map Api.ProjectId expectedProjects

    describe "getProject" $ do
      it "serves the expected project" $
        TestApp.withPlecoServer $ \port -> do
          project <- TestApp.client port (Client.getProject (Api.ProjectId "pleco"))
          Api.prjId project `shouldBe` Api.ProjectId "pleco"

      it "returns 404 on project that does not exist" $
        TestApp.withPlecoServerCatching $ \port ->
          TestApp.client port (Client.getProject (Api.ProjectId "bogus-project"))
            `shouldThrow` TestApp.hasStatus status404

      it "serves problem+json on project that does not exist" $
        TestApp.withPlecoServerCatching $ \port -> do
          result <- try $ TestApp.client port (Client.getProject (Api.ProjectId "bogus-project"))
          TestApp.withProblemResponse result $ \problem -> do
            Api.pdType problem `shouldBe` Api.problemTypeUri Api.NoSuchProject
            Api.pdStatus problem `shouldBe` Api.StatusCode 404
