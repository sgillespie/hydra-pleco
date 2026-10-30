module Hydra.Pleco.Server.ProjectsSpec (spec) where

import Hydra.Pleco.Api
  ( ProblemDetails (..),
    Project (..),
    ProjectId (..),
    StatusCode (..),
  )
import Hydra.Pleco.Client (PlecoClient, PlecoClientError)

import Hydra.Pleco.Client qualified as Client
import Hydra.Pleco.Server (PlecoServerEnv)
import Hydra.Pleco.Server.TestApp (mkTestEnv, withPlecoApp, withPlecoAppCatching)

import Data.Aeson qualified as Aeson
import Hasql.Pool (Pool)
import Network.HTTP.Types (Status)
import Network.HTTP.Types.Status (status404)
import Network.URI (URI (..), nullURI)
import Network.Wai.Handler.Warp (Port)
import Servant.Client (BaseUrl (..), Scheme (Http))
import Test.Hspec
import UnliftIO (throwIO, try)

spec :: SpecWith (Text, Pool)
spec = describe "Hydra.Pleco.Server.Projects" $ do
  describe "projects" $ do
    describe "listProjects" $ do
      it "lists every project" $
        withServer $ \port -> do
          projects <- client port Client.listProjects
          map prjId projects `shouldMatchList` map ProjectId ["pleco", "hidden", "paused"]

    describe "getProject" $ do
      it "serves the expected project" $
        withServer $ \port -> do
          project <- client port (Client.getProject (ProjectId "pleco"))
          prjId project `shouldBe` ProjectId "pleco"

      it "returns 404 on project that does not exist" $
        withServerCatching $ \port ->
          client port (Client.getProject (ProjectId "bogus-project"))
            `shouldThrow` hasStatus status404

      it "serves problem+json on project that does not exist" $
        withServerCatching $ \port -> do
          result <- try $ client port (Client.getProject (ProjectId "bogus-project"))

          problem <- case result of
            Left (Client.PlecoFailureResponse _ _ body) ->
              either fail pure (Aeson.eitherDecodeStrict body)
            Left err -> throwIO err
            Right _ -> fail "expected a failure response"

          pdType problem `shouldBe` nullURI {uriPath = "/problems/no-such-project"}
          pdStatus problem `shouldBe` StatusCode 404

-- Start the test server, run an action, then shut it down
withServer :: (Port -> IO a) -> ((Text, Pool) -> IO a)
withServer = withServerUsing withPlecoApp

-- Same as 'withServer', but all exceptions are silently ignored
withServerCatching :: (Port -> IO a) -> ((Text, Pool) -> IO a)
withServerCatching = withServerUsing withPlecoAppCatching

-- Initialize a test 'PlecoServerEnv', then pass it to the specified 'serve' and 'act'
-- actions
withServerUsing
  :: (PlecoServerEnv -> (Port -> IO a) -> IO a)
  -> (Port -> IO a)
  -> ((Text, Pool) -> IO a)
withServerUsing serve act (connInfo, pool) = do
  env <- mkTestEnv connInfo pool []
  serve env act

-- Run a real request against the test server and return the result
client :: Port -> PlecoClient a -> IO a
client port act = do
  env <- Client.mkPlecoClientEnv (BaseUrl Http "localhost" port "")
  Client.runPlecoClient env act

-- Returns true if the the error is 'Client.PlecoFailureResponse', and its status matches
-- the one specified.
hasStatus :: Status -> Selector PlecoClientError
hasStatus code (Client.PlecoFailureResponse _ status _) = status == code
hasStatus _ _ = False
