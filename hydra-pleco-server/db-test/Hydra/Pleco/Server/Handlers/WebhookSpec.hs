module Hydra.Pleco.Server.Handlers.WebhookSpec (spec) where

import Hydra.Pleco.Api
  ( EventType (..),
    JobsetEvent (..),
    JobsetName (..),
    ProjectId (..),
    Subscription (..),
  )
import Hydra.Pleco.Client.EchoServer (jobsetEventApp)
import Hydra.Pleco.Server (runPlecoServerT)
import Hydra.Pleco.Server.Handlers.Webhook (sendWebhook, watchHydraEvents)
import Hydra.Pleco.Server.Monad (PlecoServerEnv (..))
import Hydra.Pleco.Server.TestApp (mkTestEnv)

import Hasql.Pool (Pool)
import Hasql.Pool qualified as Pool
import Hasql.Session qualified as Session
import Network.Wai.Handler.Warp (Port)
import Network.Wai.Handler.Warp qualified as Warp
import Test.Hspec
import UnliftIO (throwIO)
import UnliftIO.Async qualified as Async
import UnliftIO.Concurrent (threadDelay)

notifyRounds :: Int
notifyRounds = 200

pollMicros :: Int
pollMicros = 25_000

settleMicros :: Int
settleMicros = 500_000

spec :: SpecWith (Text, Pool)
spec = describe "Hydra.Pleco.Server.Handlers.Webhook" $ do
  describe "sendWebhook" $
    it "sends the expected event" $ \(connInfo, pool) ->
      withReceiver $ \port received -> do
        env <- mkTestEnv connInfo pool []
        runPlecoServerT env (sendWebhook event (subscriptionAt port))
        readTVarIO received `shouldReturn` [event]

  describe "watchHydraEvents" $ do
    it "delivers a Hydra notification to a webhook" $ \(connInfo, pool) ->
      withReceiver $ \port received -> do
        env <- mkTestEnv connInfo pool [subscriptionAt port]
        Async.withAsync (runPlecoServerT env watchHydraEvents) $ \_ -> do
          ev <- notifyUntilDelivered pool received
          ev
            `shouldBe` JobsetEvent
              { jeEventType = EvalAdded,
                jeProject = ProjectId "pleco",
                jeJobset = JobsetName "main"
              }

    -- TODO[sgillespie]: This should skip over the failed delivery, then attempt to
    -- deliver the rest
    it "skips the subscribers after one that fails" $ \(connInfo, pool) ->
      withReceiver $ \port received -> do
        env <- mkTestEnv connInfo pool [subscriptionAt port]
        Async.withAsync (runPlecoServerT env watchHydraEvents) $ \_ -> do
          _ <- notifyUntilDelivered pool received

          atomically $ writeTVar (pseSubscriptions env) [unreachable, subscriptionAt port]
          -- Let anything in flight complete
          threadDelay settleMicros
          atomically $ writeTVar received []

          replicateM_ notifyRounds (notifyEvalAdded pool >> threadDelay pollMicros)
          readTVarIO received `shouldReturn` []

event :: JobsetEvent
event =
  JobsetEvent
    { jeEventType = EvalAdded,
      jeProject = ProjectId "pleco",
      jeJobset = JobsetName "main"
    }

subscriptionAt :: Port -> Subscription
subscriptionAt port = Subscription ("http://localhost:" <> show port <> "/")

-- | Simulate an unreachable host with connection refused
unreachable :: Subscription
unreachable = Subscription "http://localhost:1/"

-- | Serve the reference callback, recording what arrives instead of logging it
withReceiver :: (Port -> TVar [JobsetEvent] -> IO a) -> IO a
withReceiver act = do
  received <- newTVarIO []
  let record ev = atomically $ modifyTVar' received (<> [ev])
  Warp.testWithApplication (pure (jobsetEventApp record)) $ \port ->
    act port received

-- | @NOTIFY@ has no backlog, so keep firing until something arrives.
notifyUntilDelivered :: Pool -> TVar [JobsetEvent] -> IO JobsetEvent
notifyUntilDelivered pool received = go notifyRounds
  where
    go 0 = fail "no webhook was delivered"
    go n = do
      notifyEvalAdded pool
      threadDelay pollMicros
      readTVarIO received >>= \case
        [] -> go (n - 1 :: Int)
        (ev : _) -> pure ev

-- | Forge a Hydra notification
notifyEvalAdded :: Pool -> IO ()
notifyEvalAdded pool = do
  res <- Pool.use pool (Session.sql "select pg_notify('eval_added', 'trace\t1\t1')")
  either throwIO pure res
