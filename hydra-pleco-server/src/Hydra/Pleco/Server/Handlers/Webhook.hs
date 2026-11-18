module Hydra.Pleco.Server.Handlers.Webhook
  ( webhooksHandler,
    webhooksSubscribeHandler,
    webhooksListHandler,
    watchHydraEvents,
    sendWebhook,
    fromHydraNotification,
  ) where

import Hydra.Pleco.Api
import Hydra.Pleco.Server.DB (HydraNotification, hydraNotifyChannels, newConnection, parseHydraNotification, releaseConnection, runSession)
import Hydra.Pleco.Server.Error (PlecoServerError (..))
import Hydra.Pleco.Server.Handlers.Webhook.DB (fromHydraNotification)
import Hydra.Pleco.Server.Monad (PlecoServerEnv (..), PlecoServerT)

import Hasql.Notifications (listen, toPgIdentifier, waitForNotifications)
import Katip qualified
import Servant (Handler, HasServer (..), NamedRoutes)
import Servant.Client (AsClientT, ClientM, (//), (/:))
import Servant.Client qualified as Servant
import Servant.Client.Generic (genericClient)
import Servant.Server (ServerError)
import UnliftIO (MonadUnliftIO (..), bracket, catches, modifyTVar, throwIO)
import UnliftIO.Exception qualified as Exception

webhooksHandler :: ServerT (NamedRoutes WebhooksApi) (PlecoServerT Handler)
webhooksHandler =
  WebhooksApi
    { whaSubscribe = webhooksSubscribeHandler,
      whaList = webhooksListHandler
    }

webhooksSubscribeHandler :: Subscription -> PlecoServerT Handler Subscription
webhooksSubscribeHandler sub = do
  subs <- asks pseSubscriptions
  atomically $ modifyTVar subs (sub :)
  pure sub

webhooksListHandler :: PlecoServerT Handler [Subscription]
webhooksListHandler = readTVarIO =<< asks pseSubscriptions

watchHydraEvents :: PlecoServerT IO ()
watchHydraEvents = do
  connInfo <- asks pseDbConnInfo
  bracket (newConnection connInfo) releaseConnection $ \conn ->
    withRunInIO $ \run -> do
      -- Register this session as listener to hydra-notify channels (eval_started,
      -- eval_added, etc)
      mapM_ (listen conn . toPgIdentifier) hydraNotifyChannels
      -- Wait for notifications and process them one at a time
      flip waitForNotifications conn $ \chan payload -> run $ do
        let notification = parseHydraNotification (decodeUtf8 chan) (decodeUtf8 payload)
        case notification of
          Left err -> Katip.logFM Katip.ErrorS $ Katip.showLS err
          Right parsed -> do
            catches
              (handleNotification parsed)
              [ Exception.Handler $ \(err :: ServerError) ->
                  Katip.logFM Katip.WarningS $ "Received invalid response: " <> Katip.showLS err,
                Exception.Handler $ \(err :: SomeException) ->
                  Katip.logFM Katip.ErrorS $ Katip.showLS err
              ]

handleNotification :: HydraNotification -> PlecoServerT IO ()
handleNotification notification = do
  Katip.logFM Katip.InfoS $
    "Received Hydra event: " <> show notification

  PlecoServerEnv {pseDbPool, pseSubscriptions} <- ask
  subs <- readTVarIO pseSubscriptions

  void . runMaybeT $ do
    event <- MaybeT $ runSession pseDbPool (fromHydraNotification notification)
    forM_ subs $ \sub -> do
      lift $ sendWebhook event sub
      Katip.logFM Katip.InfoS $ "Successfully sent webhook to " <> Katip.showLS sub

sendWebhook :: JobsetEvent -> Subscription -> PlecoServerT IO ()
sendWebhook reqPayload (Subscription url) = do
  manager' <- asks pseClientManager
  baseUrl <- Servant.parseBaseUrl (toString url)
  let env' = Servant.mkClientEnv manager' baseUrl
  res <- liftIO $ Servant.runClientM (postWebhook reqPayload) env'

  either
    (throwIO . ServerClientError)
    pure
    res

postWebhook :: JobsetEvent -> ClientM ()
postWebhook event = webhookClient // webhook /: event

webhookClient :: JobsetEventApi (AsClientT ClientM)
webhookClient = genericClient
