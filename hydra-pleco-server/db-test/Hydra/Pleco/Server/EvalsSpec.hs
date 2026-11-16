module Hydra.Pleco.Server.EvalsSpec (spec) where

import Hydra.Pleco.Api
  ( Eval (..),
    EvalId (..),
    JobsetName (..),
    ProblemDetails (..),
    ProblemType (..),
    ProjectId (..),
    StatusCode (..),
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
spec = describe "Hydra.Pleco.Server.Evals" $ do
  describe "evals" $ do
    describe "listEvals" $ do
      it "lists every eval for a jobset" $ do
        withPlecoServer $ \port -> do
          evals <-
            client port $
              Client.listEvals (Client.JobsetSpec (ProjectId "pleco") (JobsetName "main"))
          map evId evals `shouldMatchList` [EvalId 1]

      -- TODO[sgillespie]: Should also fail on jobset that doesn't exist
      it "returns 404 when project does not exist" $
        withPlecoServerCatching $ \port ->
          let listEvals' =
                Client.listEvals $
                  Client.JobsetSpec (ProjectId "bogus-project") (JobsetName "main")
          in  client port listEvals' `shouldThrow` hasStatus status404

      it "serves problem+json when project does not exist" $
        withPlecoServerCatching $ \port -> do
          result <-
            try . client port $
              Client.listEvals $
                Client.JobsetSpec (ProjectId "bogus-project") (JobsetName "main")

          withProblemResponse result $ \problem ->
            pdType problem `shouldBe` problemTypeUri NoSuchProject

    describe "getEval" $ do
      it "serves the expected eval" $
        withPlecoServer $ \port -> do
          eval <- client port (Client.getEval $ EvalId 1)
          evId eval `shouldBe` EvalId 1

      it "returns 404 when eval does not exist" $
        withPlecoServerCatching $ \port -> do
          client port (Client.getEval $ EvalId 999) `shouldThrow` hasStatus status404

      it "serves problem+json when eval does not exist" $
        withPlecoServerCatching $ \port -> do
          result <- try . client port $ Client.getEval (EvalId 999)
          withProblemResponse result $ \problem ->
            pdType problem `shouldBe` problemTypeUri NoSuchEval

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
