module Hydra.Pleco.Server
  ( PlecoServerT (..),
    PlecoServerEnv (..),
    runPlecoServerT,
    mkPlecoServerEnv,
    runApp,
    app,
  ) where

import Hydra.Pleco.Api (Health (..), HydraApi (..), HydraApp (..), Subscription, WebhooksApi (..), hydraOpenApi)

import Control.Exception (finally)
import Data.Text.Lazy.Builder (fromText)
import Katip
  ( ItemFormatter,
    Katip,
    KatipContext,
    LogContexts,
    LogEnv,
    LogItem,
    Namespace,
    renderSeverity,
    unLogStr,
  )
import Katip qualified
import Katip.Core qualified as Katip
import Katip.Format.Time (formatAsLogTime)
import Katip.Scribes.Handle qualified as Katip
import Network.Wai.Handler.Warp (Port, run)
import Servant
import Servant.Server.Generic (genericServeT)
import Servant.Swagger.UI (swaggerSchemaUIServerT)
import UnliftIO (MonadUnliftIO, modifyTVar)

-- | The application monad stack
newtype PlecoServerT m a = PlecoServerT {unPlecoServerT :: ReaderT PlecoServerEnv m a}
  deriving newtype
    ( Functor,
      Applicative,
      Monad,
      MonadReader PlecoServerEnv,
      MonadIO,
      MonadUnliftIO
    )

-- | The reader environment
data PlecoServerEnv = PlecoServerEnv
  { pseLogNamespace :: Namespace,
    pseLogCtx :: LogContexts,
    pseLogEnv :: LogEnv,
    pseSubscriptions :: TVar [Subscription]
  }

instance (MonadIO io) => Katip (PlecoServerT io) where
  getLogEnv = asks pseLogEnv
  localLogEnv f (PlecoServerT m) =
    PlecoServerT $
      local
        (\env@PlecoServerEnv {..} -> env {pseLogEnv = f pseLogEnv})
        m

instance (MonadIO io) => KatipContext (PlecoServerT io) where
  getKatipContext = asks pseLogCtx

  localKatipContext f (PlecoServerT m) =
    PlecoServerT $
      local (\env@PlecoServerEnv {..} -> env {pseLogCtx = f pseLogCtx}) m

  getKatipNamespace = asks pseLogNamespace

  localKatipNamespace f (PlecoServerT m) =
    PlecoServerT $
      local (\env@PlecoServerEnv {..} -> env {pseLogNamespace = f pseLogNamespace}) m

runPlecoServerT :: PlecoServerEnv -> PlecoServerT m a -> m a
runPlecoServerT env = usingReaderT env . unPlecoServerT

-- | Katip's built-in 'bracketFormat' copied here, with some fields omitted. The
-- following fields have been removed:
--
--  * PID
--  * Thread ID
logFormat :: (LogItem a) => ItemFormatter a
logFormat withColor verb Katip.Item {..} =
  Katip.brackets nowStr
    <> Katip.brackets (mconcat $ map fromText $ Katip.intercalateNs _itemNamespace)
    <> Katip.brackets (fromText (renderSeverity' _itemSeverity))
    <> Katip.brackets (fromString _itemHost)
    <> mconcat ks
    <> maybe mempty (Katip.brackets . fromString . Katip.locationToString) _itemLoc
    <> fromText " "
    <> unLogStr _itemMessage
  where
    nowStr = fromText (formatAsLogTime _itemTime)
    ks = map Katip.brackets $ Katip.getKeys verb _itemPayload
    renderSeverity' severity =
      Katip.colorBySeverity withColor severity (renderSeverity severity)

mkPlecoServerEnv :: IO PlecoServerEnv
mkPlecoServerEnv = do
  logEnv <- Katip.initLogEnv "hydra-pleco" "production"
  scribe <-
    Katip.mkHandleScribeWithFormatter
      logFormat
      Katip.ColorIfTerminal
      stderr
      (Katip.permitItem Katip.InfoS)
      Katip.V2
  logEnv' <- Katip.registerScribe "stderr" scribe Katip.defaultScribeSettings logEnv
  subs <- newTVarIO []

  pure
    PlecoServerEnv
      { pseLogNamespace = "default",
        pseLogCtx = mempty,
        pseLogEnv = logEnv',
        pseSubscriptions = subs
      }

app :: PlecoServerEnv -> Application
app env = genericServeT (runPlecoServerT env) server

runApp :: Port -> PlecoServerEnv -> IO ()
runApp port env@(PlecoServerEnv {..}) = runPlecoServerT env $ do
  Katip.logFM Katip.InfoS $ "Starting pleco-server at http://localhost:" <> show port
  liftIO $ run port (app env) `finally` Katip.closeScribes pseLogEnv

server :: ServerT (NamedRoutes HydraApp) (PlecoServerT Handler)
server =
  HydraApp
    { api = apiServer,
      docs = swaggerSchemaUIServerT hydraOpenApi
    }

apiServer :: ServerT (NamedRoutes HydraApi) (PlecoServerT Handler)
apiServer =
  HydraApi
    { health = healthHandler,
      webhooks = webhooksHandler
    }

healthHandler :: PlecoServerT Handler Health
healthHandler = pure (Health "pass")

webhooksHandler :: ServerT (NamedRoutes WebhooksApi) (PlecoServerT Handler)
webhooksHandler =
  WebhooksApi
    { subscribe = webhooksSubscribeHandler,
      list = webhooksListHandler
    }

webhooksSubscribeHandler :: Subscription -> PlecoServerT Handler Subscription
webhooksSubscribeHandler sub = do
  subs <- asks pseSubscriptions
  atomically $ modifyTVar subs (sub :)
  pure sub

webhooksListHandler :: PlecoServerT Handler [Subscription]
webhooksListHandler = readTVarIO =<< asks pseSubscriptions
