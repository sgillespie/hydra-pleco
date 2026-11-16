module Hydra.Pleco.Server
  ( PlecoServerT (..),
    PlecoServerEnv (..),
    runPlecoServerT,
    mkPlecoServerEnv,
    runServer,
    app,
  ) where

import Hydra.Pleco.Api (Health (..), HydraApi (..), HydraApp (..))
import Hydra.Pleco.Api.OpenApi (hydraOpenApi)
import Hydra.Pleco.Server.DB (releaseConnectionPool, testConnection)
import Hydra.Pleco.Server.Monad
import Hydra.Pleco.Server.Projects (projectsHandler)
import Hydra.Pleco.Server.Webhook (watchHydraEvents, webhooksHandler)

import Data.Aeson ((.=))
import Data.Aeson qualified as Aeson
import Data.UUID qualified as UUID
import Hasql.Pool (Pool)
import Hydra.Pleco.Server.Evals (evalsHandler)
import Hydra.Pleco.Server.Jobsets (jobsetsHandler)
import Katip qualified
import Katip.Wai (ApplicationT, Formatter, MiddlewareT, Request, Response)
import Katip.Wai qualified as KatipWai
import Katip.Wai.Request qualified as Request
import Network.HTTP.Types (Status (..))
import Network.Wai.Handler.Warp (Port, Settings)
import Network.Wai.Handler.Warp qualified as Warp
import Servant (Application, Handler, HasServer (..), NamedRoutes)
import Servant.Server.Generic (genericServeT)
import Servant.Swagger.UI (swaggerSchemaUIServerT)
import System.Clock (TimeSpec, toNanoSecs)
import UnliftIO (MonadUnliftIO (..), bracket_)
import UnliftIO.Async qualified as Async

runServer :: Port -> PlecoServerEnv -> IO ()
runServer port env = runPlecoServerT env $ do
  Async.mapConcurrently_
    id
    [ Katip.katipAddNamespace "server" (runApp port),
      Katip.katipAddNamespace "watcher" runHydraWatcher
    ]

runApp :: Port -> PlecoServerT IO ()
runApp port = do
  env@PlecoServerEnv {pseDbConnInfo, pseDbPool} <- ask

  Katip.logFM Katip.InfoS $ "Starting pleco-server at http://localhost:" <> show port
  bracket_
    (init' pseDbConnInfo pseDbPool)
    (finalize pseDbPool)
    (liftIO $ Warp.runSettings (settings port) (app env))
  where
    init' :: Text -> Pool -> PlecoServerT IO ()
    init' connInfo dbPool = do
      -- Test connecting to the database, log and fail on exception
      testConnection dbPool `Katip.logExceptionM` Katip.ErrorS
      Katip.logFM Katip.InfoS $ "Connection to database '" <> Katip.ls connInfo <> "' successful"

    finalize :: Pool -> PlecoServerT IO ()
    finalize dbPool = do
      Katip.logFM Katip.InfoS $ "Stopped pleco-server at http://localhost:" <> show port
      releaseConnectionPool dbPool

runHydraWatcher :: PlecoServerT IO ()
runHydraWatcher = do
  connInfo <- asks pseDbConnInfo
  Katip.logFM Katip.InfoS $ "Starting Hydra watcher at '" <> Katip.ls connInfo <> "'"
  watchHydraEvents

settings :: Port -> Settings
settings port = Warp.setPort port Warp.defaultSettings

app :: PlecoServerEnv -> Application
app env = KatipWai.runApplication (runPlecoServerT env) mkApplication

mkApplication :: ApplicationT (PlecoServerT IO)
mkApplication = loggingMiddleware $ \req send -> do
  env <- ask
  let serveApp = genericServeT (runPlecoServerT env) server
  withRunInIO $ \run -> serveApp req (run . send)

loggingMiddleware :: MiddlewareT (PlecoServerT IO)
loggingMiddleware = KatipWai.middlewareCustom logOpts
  where
    logOpts =
      mconcat
        [ KatipWai.addRequestAndResponseToContext requestFormat responseFormat,
          logRequest
        ]

    requestFormat :: Formatter Request
    requestFormat req =
      Aeson.object
        [ "id" .= UUID.toText (Request.traceId req),
          "method" .= decodeUtf8 @Text (Request.method req),
          "path" .= decodeUtf8 @Text (Request.rawPathInfo req)
        ]

    responseFormat :: Formatter Response
    responseFormat resp =
      Aeson.object
        [ "status" .= statusCode (KatipWai.status resp),
          "duration_ms" .= formatMs (KatipWai.responseTime resp)
        ]

    formatMs :: TimeSpec -> Double
    formatMs timeSpec = fromIntegral (toNanoSecs timeSpec)

    logRequest =
      KatipWai.Options
        { handleRequest = \_ action -> do
            Katip.katipAddNamespace "access" $ Katip.logFM Katip.InfoS "Request received."
            action,
          handleResponse = \_ action -> do
            Katip.katipAddNamespace "access" $ Katip.logFM Katip.InfoS "Response sent."
            action
        }

server :: ServerT (NamedRoutes HydraApp) (PlecoServerT Handler)
server =
  HydraApp
    { appApi = apiServer,
      appDocs = swaggerSchemaUIServerT hydraOpenApi
    }

apiServer :: ServerT (NamedRoutes HydraApi) (PlecoServerT Handler)
apiServer =
  HydraApi
    { apiHealth = healthHandler,
      apiWebhooks = webhooksHandler,
      apiProjects = projectsHandler,
      apiJobsets = jobsetsHandler,
      apiEvals = evalsHandler
    }

healthHandler :: PlecoServerT Handler Health
healthHandler = pure (Health "pass")
