module Hydra.Pleco.Server.JobsetsSpec (spec) where

import Hydra.Pleco.Api
  ( JobsetId (..),
    JobsetName (..),
    ProblemDetails,
    ProblemType (..),
    ProjectId (..),
    StatusCode (..),
    jsId,
    pdStatus,
    pdType,
    problemTypeUri,
  )
import Hydra.Pleco.Client (PlecoClient, PlecoClientError)
import Hydra.Pleco.Client qualified as Client
import Hydra.Pleco.Server.TestApp (withPlecoServer, withPlecoServerCatching)

import Hasql.Pool (Pool)
import Network.HTTP.Types (Status (..), status404)
import Network.Wai.Handler.Warp (Port)
import Servant.Client (BaseUrl (..), Scheme (..))
import Test.Hspec (Expectation, Selector, SpecWith, describe, it, shouldBe, shouldMatchList, shouldThrow)
import UnliftIO (throwIO, try)

spec :: SpecWith (Text, Pool)
spec = describe "Hydra.Pleco.Server.Jobsets" $ do
  describe "jobsets" $ do
    describe "listJobsets" $ do
      it "lists every jobset for a project" $
        withPlecoServer $ \port -> do
          jobsets <- client port (Client.listJobsets (ProjectId "pleco") Nothing)
          map jsId jobsets `shouldMatchList` map JobsetId [1, 2]

      it "filters by jobset name" $
        withPlecoServer $ \port -> do
          jobsets <-
            client port $
              Client.listJobsets (ProjectId "pleco") (Just (JobsetName "main"))
          map jsId jobsets `shouldMatchList` [JobsetId 1]

      it "returns empty when filter does not match any jobset" $
        withPlecoServer $ \port -> do
          jobsets <-
            client port $
              Client.listJobsets (ProjectId "pleco") (Just (JobsetName "bogus-jobset"))
          map jsId jobsets `shouldMatchList` []

      it "returns 404 when project does not exist" $
        withPlecoServerCatching $ \port -> do
          -- Should throw 404 without jobset filter
          client port (Client.listJobsets (ProjectId "bogus-project") Nothing)
            `shouldThrow` hasStatus status404

          -- And with a jobset filter
          client port (Client.listJobsets (ProjectId "bogus-project") (Just (JobsetName "main")))
            `shouldThrow` hasStatus status404

      it "serves problem+json on project that does not exist" $
        withPlecoServerCatching $ \port -> do
          -- Should return problem+json without jobset filter
          result <-
            try . client port $
              Client.listJobsets (ProjectId "bogus-project") Nothing
          withProblemResponse result $ \problem ->
            pdType problem `shouldBe` problemTypeUri NoSuchProject

          -- And with jobset filter
          result' <-
            try . client port $
              Client.listJobsets
                (ProjectId "bogus-project")
                (Just $ JobsetName "main")
          withProblemResponse result' $ \problem ->
            pdType problem `shouldBe` problemTypeUri NoSuchProject

    describe "getJobset" $ do
      it "serves the expected jobset" $
        withPlecoServer $ \port -> do
          jobset <- client port $ Client.getJobset (JobsetId 1)
          jsId jobset `shouldBe` JobsetId 1

      it "returns 404 when jobset does not exist" $
        withPlecoServerCatching $ \port -> do
          client port (Client.getJobset $ JobsetId 999)
            `shouldThrow` hasStatus status404

      it "serves problem+json on jobset that does not exist" $
        withPlecoServerCatching $ \port -> do
          result <- try . client port $ Client.getJobset (JobsetId 999)
          withProblemResponse result $ \problem ->
            pdType problem `shouldBe` problemTypeUri NoSuchJobset

-- TODO[sgillespie]: Move the following to testlib

-- | Run a real request against the test server and return the result
client :: Port -> PlecoClient a -> IO a
client port act = do
  env <- Client.mkPlecoClientEnv (BaseUrl Http "localhost" port "")
  Client.runPlecoClient env act

-- Returns true if the error is a 'Client.PlecoProblemResponse' and its status matches
-- the one specified.
hasStatus :: Status -> Selector PlecoClientError
hasStatus code (Client.PlecoProblemResponse problem) =
  pdStatus problem == StatusCode (statusCode code)
hasStatus _ _ = False

-- | Checks an API result, expected to be a 'PlecoProblemResponse', then passes the
-- 'ProblemDetails' to the given 'Expectation'. If the result was successful or not a
-- problem response, it fails the test.
withProblemResponse
  :: Either PlecoClientError a
  -> (ProblemDetails -> Expectation)
  -> Expectation
withProblemResponse result expect =
  case result of
    Left (Client.PlecoProblemResponse problem) -> expect problem
    Left err -> throwIO err
    Right _ -> fail "expected a failure response"
