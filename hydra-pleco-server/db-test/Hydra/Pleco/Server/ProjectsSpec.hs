module Hydra.Pleco.Server.ProjectsSpec (spec) where

import Hydra.Pleco.Api
  ( ProblemDetails (..),
    ProblemType (..),
    Project (..),
    ProjectId (..),
    StatusCode (..),
    problemTypeUri,
  )
import Hydra.Pleco.Client (PlecoClient, PlecoClientError)

import Hydra.Pleco.Client qualified as Client
import Hydra.Pleco.Server.TestApp (withPlecoServer, withPlecoServerCatching)

import Hasql.Pool (Pool)
import Network.HTTP.Types (Status (..))
import Network.HTTP.Types.Status (status404)
import Network.Wai.Handler.Warp (Port)
import Servant.Client (BaseUrl (..), Scheme (Http))
import Test.Hspec
import UnliftIO (throwIO, try)

spec :: SpecWith (Text, Pool)
spec = describe "Hydra.Pleco.Server.Projects" $ do
  describe "projects" $ do
    describe "listProjects" $ do
      it "lists every project" $
        withPlecoServer $ \port -> do
          projects <- client port Client.listProjects
          map prjId projects `shouldMatchList` map ProjectId ["pleco", "hidden", "paused"]

    describe "getProject" $ do
      it "serves the expected project" $
        withPlecoServer $ \port -> do
          project <- client port (Client.getProject (ProjectId "pleco"))
          prjId project `shouldBe` ProjectId "pleco"

      it "returns 404 on project that does not exist" $
        withPlecoServerCatching $ \port ->
          client port (Client.getProject (ProjectId "bogus-project"))
            `shouldThrow` hasStatus status404

      it "serves problem+json on project that does not exist" $
        withPlecoServerCatching $ \port -> do
          result <- try $ client port (Client.getProject (ProjectId "bogus-project"))

          problem <- case result of
            Left (Client.PlecoProblemResponse problem) -> pure problem
            Left err -> throwIO err
            Right _ -> fail "expected a failure response"

          pdType problem `shouldBe` problemTypeUri NoSuchProject
          pdStatus problem `shouldBe` StatusCode 404

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
