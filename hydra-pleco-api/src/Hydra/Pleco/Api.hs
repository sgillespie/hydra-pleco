module Hydra.Pleco.Api
  ( HydraApi (..),
    WebhooksApi (..),
    HydraApp (..),
    HealthJSON,
    Health (..),
    Subscription (..),
    JobsetEvent (..),
    EventType (..),
    Project (..),
    Jobset (..),
    hydraApi,
    hydraOpenApi,
  ) where

import Data.Aeson
  ( FromJSON,
    KeyValue (..),
    ToJSON,
    (.:),
  )
import Data.Aeson qualified as Aeson
import Data.HashMap.Strict.InsOrd.Compat qualified as InsOrd
import Data.OpenApi
  ( Callback,
    Definitions,
    NamedSchema (..),
    OpenApi,
    Operation,
    Referenced,
    RequestBody,
    Schema,
    ToSchema,
  )
import Data.OpenApi qualified as OpenApi
import Data.OpenApi.Declare (execDeclare)
import Network.HTTP.Media ((//))
import Optics (At (..), (%), (%~), (.~), (?~))
import Optics.Extra (_Just)
import Relude.Extra (safeToEnum)
import Servant.API
import Servant.OpenApi (HasOpenApi (..))
import Servant.Swagger.UI (SwaggerSchemaUI)

-- | Documented API routes. OpenApi spec is generated from this.
data HydraApi mode = HydraApi
  { health :: mode :- "health" :> Get '[HealthJSON] Health,
    webhooks :: mode :- "webhooks" :> NamedRoutes WebhooksApi
  }
  deriving stock (Generic)

data WebhooksApi mode = WebhooksApi
  { subscribe :: mode :- ReqBody '[JSON] Subscription :> PostCreated '[JSON] Subscription,
    list :: mode :- Get '[JSON] [Subscription]
  }
  deriving stock (Generic)

-- | The full Rest API application: the documented routes plus the Swagger UI.
data HydraApp mode = HydraApp
  { api :: mode :- NamedRoutes HydraApi,
    docs :: mode :- SwaggerSchemaUI "swagger-ui" "swagger.json"
  }
  deriving stock (Generic)

newtype Health = Health
  {status :: Text}
  deriving stock (Eq, Show, Generic)
  deriving anyclass (ToSchema)

data HealthJSON

newtype Subscription = Subscription
  {url :: Text}
  deriving stock (Eq, Show, Generic)
  deriving anyclass (ToSchema)

data JobsetEvent = JobsetEvent
  { jeEventType :: EventType,
    jeProject :: Project,
    jeJobset :: Jobset
  }
  deriving stock (Eq, Show, Generic)

instance ToSchema JobsetEvent where
  declareNamedSchema _ = do
    eventTypeSchema <- OpenApi.declareSchemaRef (Proxy @EventType)

    let properties =
          InsOrd.fromList
            [ ("event_type", eventTypeSchema),
              ("project", OpenApi.toSchemaRef (Proxy @Text)),
              ("jobset", OpenApi.toSchemaRef (Proxy @Text))
            ]

    pure $
      NamedSchema (Just "JobsetEvent") $
        mempty
          & #properties .~ properties
          & #required .~ ["event_type"]

data EventType
  = EvalStarted
  | EvalAdded
  | EvalCached
  | EvalFailed
  | BuildQueued
  | CachedBuildQueued
  | BuildStarted
  | BuildFinished
  | CachedBuildFinished
  deriving stock (Bounded, Eq, Enum, Ord, Show, Generic)

instance ToSchema EventType where
  declareNamedSchema _ = do
    let allEventTypes :: [EventType]
        allEventTypes = maybe [] enumFrom (safeToEnum 0)

    pure $
      NamedSchema (Just "EventType") $
        mempty
          & #enum ?~ map Aeson.toJSON allEventTypes
          & #type ?~ OpenApi.OpenApiString

newtype Project = Project {unProject :: Text}
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (ToSchema)
  deriving newtype (ToJSON, FromJSON)

newtype Jobset = Jobset {unJobset :: Text}
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (ToSchema)
  deriving newtype (ToJSON, FromJSON)

instance ToJSON Health where
  toJSON Health {..} =
    Aeson.object
      [ "status" .= status
      ]

  toEncoding Health {..} =
    Aeson.pairs $
      "status" .= status

instance FromJSON Health where
  parseJSON = Aeson.withObject "Health" $ \val ->
    Health
      <$> val .: "status"

instance Accept HealthJSON where
  contentType _ = "application" // "health+json"

instance (ToJSON json) => MimeRender HealthJSON json where
  mimeRender _ = Aeson.encode

instance (FromJSON json) => MimeUnrender HealthJSON json where
  mimeUnrender _ = Aeson.eitherDecode

instance ToJSON Subscription where
  toJSON Subscription {url} = Aeson.object ["url" .= url]
  toEncoding Subscription {url} = Aeson.pairs $ "url" .= url

instance FromJSON Subscription where
  parseJSON = Aeson.withObject "Subscription" $ \val ->
    Subscription <$> val .: "url"

instance ToJSON JobsetEvent where
  toJSON JobsetEvent {..} =
    Aeson.object
      [ "event_type" .= jeEventType,
        "project" .= jeProject,
        "jobset" .= jeJobset
      ]

  toEncoding JobsetEvent {..} =
    Aeson.pairs $
      "event_type" .= jeEventType
        <> "project" .= jeProject
        <> "jobset" .= jeJobset

instance ToJSON EventType where
  toJSON EvalStarted = "eval_started"
  toJSON EvalAdded = "eval_added"
  toJSON EvalCached = "eval_cached"
  toJSON EvalFailed = "eval_failed"
  toJSON BuildQueued = "build_queued"
  toJSON CachedBuildQueued = "cached_build_queued"
  toJSON BuildStarted = "build_started"
  toJSON BuildFinished = "build_finished"
  toJSON CachedBuildFinished = "cached_build_finished"

instance FromJSON JobsetEvent where
  parseJSON = Aeson.withObject "JobsetEvent" $ \val -> do
    eventType <- val .: "event_type"
    project <- val .: "project"
    jobset <- val .: "jobset"

    pure
      JobsetEvent
        { jeEventType = eventType,
          jeProject = project,
          jeJobset = jobset
        }

instance FromJSON EventType where
  parseJSON = Aeson.withText "EventType" $ \case
    "eval_started" -> pure EvalStarted
    "eval_added" -> pure EvalAdded
    "eval_cached" -> pure EvalCached
    "eval_failed" -> pure EvalFailed
    "build_queued" -> pure BuildQueued
    "cached_build_queued" -> pure CachedBuildQueued
    "build_started" -> pure BuildStarted
    "build_finished" -> pure BuildFinished
    "cached_build_finished" -> pure CachedBuildFinished
    e -> fail (toString e)

hydraApi :: Proxy HydraApi
hydraApi = Proxy

hydraOpenApi :: OpenApi
hydraOpenApi =
  toOpenApi (Proxy :: Proxy (NamedRoutes HydraApi))
    & #components % #schemas %~ (<> mkEventSchema)
    & #components % #callbacks % at "jobsetEvent" ?~ mkEventCallback
    & pathCallbacks "/webhooks" % at "jobsetEvent" ?~ mkCallbackEventRef
  where
    pathCallbacks path = #paths % at path % _Just % #post % _Just % #callbacks

    mkEventSchema :: Definitions Schema
    mkEventSchema =
      execDeclare (OpenApi.declareSchemaRef (Proxy @JobsetEvent)) mempty

    mkEventCallback :: Callback
    mkEventCallback =
      OpenApi.Callback $
        InsOrd.fromList [("{$request.body#/url}", mempty & #post ?~ mkEventOp)]

    mkEventOp :: Operation
    mkEventOp =
      mempty
        & #summary ?~ "Hydra Jobset event notification"
        & #description ?~ "Posted to each registered url on Hydra jobset events."
        & #requestBody ?~ OpenApi.Inline mkReqBody
        & #responses % at 200 ?~ OpenApi.Inline mempty

    mkReqBody :: RequestBody
    mkReqBody =
      mempty
        & #required ?~ True
        & #content % at "application/json" ?~ mkMediaType

    mkMediaType = mempty & #schema ?~ OpenApi.Ref (OpenApi.Reference "JobsetEvent")

    mkCallbackEventRef :: Referenced Callback
    mkCallbackEventRef = OpenApi.Ref (OpenApi.Reference "jobsetEvent")
