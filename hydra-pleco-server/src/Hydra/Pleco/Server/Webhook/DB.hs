module Hydra.Pleco.Server.Webhook.DB
  ( fromHydraNotification,
  ) where

import Hasql.Session (Session, statement)
import Hydra.Pleco.Api (EventType (..), JobsetEvent (..))
import Hydra.Pleco.Api qualified as Api
import Hydra.Pleco.Server.DB (HydraNotification (..), JobsetId, jobsetById)
import Hydra.Pleco.Server.DB.Hydra (Jobset (..))

fromHydraNotification :: HydraNotification -> Session (Maybe JobsetEvent)
fromHydraNotification notification = do
  let jobsetId = hydraNotificationJobsetId notification
  jobset <- statement () (jobsetById jobsetId)

  pure $ mkEvent <$> jobset
  where
    mkEvent jobset =
      JobsetEvent
        { jeEventType = hydraNotificationToEventType notification,
          jeProject = Api.ProjectId (jsProject jobset),
          jeJobset = Api.JobsetName (jsName jobset)
        }

-- TODO[sgillespie]: Move me to "Mapping" layer?
hydraNotificationJobsetId :: HydraNotification -> JobsetId
hydraNotificationJobsetId (HydraEvalAdded jobset _) = jobset
hydraNotificationJobsetId (HydraEvalStarted jobset) = jobset
hydraNotificationJobsetId (HydraEvalCached jobset _) = jobset
hydraNotificationJobsetId (HydraEvalFailed jobset) = jobset

hydraNotificationToEventType :: HydraNotification -> EventType
hydraNotificationToEventType (HydraEvalAdded _ _) = EvalAdded
hydraNotificationToEventType (HydraEvalStarted _) = EvalStarted
hydraNotificationToEventType (HydraEvalCached _ _) = EvalCached
hydraNotificationToEventType (HydraEvalFailed _) = EvalFailed
