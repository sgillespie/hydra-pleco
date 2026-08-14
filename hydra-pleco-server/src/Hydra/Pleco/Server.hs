module Hydra.Pleco.Server
  ( PlecoServerT (..),
    PlecoServerEnv (..),
    runPlecoServerT,
    mkPlecoServerEnv,
    runApp,
    app,
  ) where

import Hydra.Pleco.Api (Health (..), HydraApi (..), HydraApp (..), hydraOpenApi)

import Control.Exception (finally)
import Katip (Katip, KatipContext, LogContexts, LogEnv, Namespace)
import Katip qualified
import Network.Wai.Handler.Warp (Port, run)
import Servant
import Servant.Server.Generic (genericServeT)
import Servant.Swagger.UI (swaggerSchemaUIServerT)
import UnliftIO (MonadUnliftIO)

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
    pseLogEnv :: LogEnv
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

mkPlecoServerEnv :: IO PlecoServerEnv
mkPlecoServerEnv = do
  logEnv <- Katip.initLogEnv "hydra-pleco" "production"
  scribe <-
    Katip.mkHandleScribe
      Katip.ColorIfTerminal
      stderr
      (Katip.permitItem Katip.InfoS)
      Katip.V2
  logEnv' <- Katip.registerScribe "stderr" scribe Katip.defaultScribeSettings logEnv

  pure
    PlecoServerEnv
      { pseLogNamespace = "default",
        pseLogCtx = mempty,
        pseLogEnv = logEnv'
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
    { health = healthHandler
    }

healthHandler :: PlecoServerT Handler Health
healthHandler = pure (Health "pass")
