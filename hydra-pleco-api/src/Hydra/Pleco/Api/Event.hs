module Hydra.Pleco.Api.Event
  ( JobsetEvent (..),
    EventType (..),
    Project (..),
    Jobset (..),
  ) where

import Data.Aeson
  ( FromJSON,
    KeyValue (..),
    ToJSON,
    (.:),
  )
import Data.Aeson qualified as Aeson
import Data.HashMap.Strict.InsOrd.Compat qualified as InsOrd
import Data.OpenApi (ToSchema)
import Data.OpenApi qualified as OpenApi
import Optics ((.~), (?~))
import Relude.Extra (safeToEnum)

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
      OpenApi.NamedSchema (Just "JobsetEvent") $
        mempty
          & #properties .~ properties
          & #required .~ ["event_type"]

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
      OpenApi.NamedSchema (Just "EventType") $
        mempty
          & #enum ?~ map Aeson.toJSON allEventTypes
          & #type ?~ OpenApi.OpenApiString

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

newtype Project = Project {unProject :: Text}
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (ToSchema)
  deriving newtype (ToJSON, FromJSON)

newtype Jobset = Jobset {unJobset :: Text}
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (ToSchema)
  deriving newtype (ToJSON, FromJSON)
