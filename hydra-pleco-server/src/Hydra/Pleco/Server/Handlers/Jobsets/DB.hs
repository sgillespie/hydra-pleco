module Hydra.Pleco.Server.Handlers.Jobsets.DB
  ( fromJobset,
    toJobset,
  ) where

import Data.Text qualified as Text
import Hydra.Pleco.Api qualified as Api
import Hydra.Pleco.Server.DB.Hydra qualified as Db
import Rel8 (Result)

fromJobset :: Db.Jobset Result -> Api.Jobset
fromJobset Db.Jobset {..} =
  Api.Jobset
    { jsName = Api.JobsetName jsName,
      jsProject = Api.ProjectId jsProject,
      jsId = Api.JobsetId $ fromIntegral (Db.unJobsetId jsId),
      jsState = state',
      jsVisible = not jsHidden,
      jsType = type',
      jsFlake = jsFlake,
      jsNixExprInput = jsNixExprInput,
      jsNixExprPath = jsNixExprPath,
      jsDescription = jsDescription,
      jsCheckInterval = fromIntegral jsCheckInterval,
      jsSchedulingShares = fromIntegral jsSchedulingShares,
      jsEnableDynRunCmd = jsEnableDynCmd,
      jsEnableEmail = jsEnableEmail,
      jsEmailOverride = if Text.null jsEmailOverride then Nothing else Just jsEmailOverride,
      jsKeepNumEvals = fromIntegral jsKeepNumEvals,
      jsLastCheckedTime = fromIntegral <$> jsLastCheckedTime,
      jsLastEvalTime = fromIntegral <$> jsTriggerTime,
      jsErrorMsg = jsErrorMsg,
      jsErrorTime = fromIntegral <$> jsErrorTime
    }
  where
    state' =
      case jsEnabled of
        0 -> Api.JssDisabled
        1 -> Api.JssDisabled
        2 -> Api.JssOneShot
        3 -> Api.JssOneAtATime
        _ -> Api.JssDisabled

    type' =
      case jsType of
        0 -> Api.JstLegacy
        _ -> Api.JstFlake

toJobset :: Api.Jobset -> Db.Jobset Result
toJobset Api.Jobset {..} =
  Db.Jobset
    { jsName = Api.unJobsetName jsName,
      jsId = Db.JobsetId $ fromIntegral (Api.unJobsetId jsId),
      jsProject = Api.unProjectId jsProject,
      jsDescription = jsDescription,
      jsNixExprInput = jsNixExprInput,
      jsNixExprPath = jsNixExprPath,
      jsErrorMsg = jsErrorMsg,
      jsErrorTime = fromIntegral <$> jsErrorTime,
      jsLastCheckedTime = fromIntegral <$> jsLastCheckedTime,
      jsTriggerTime = fromIntegral <$> jsLastCheckedTime,
      jsEnabled = enabled',
      jsEnableEmail = jsEnableEmail,
      jsEmailOverride = fromMaybe "" jsEmailOverride,
      jsKeepNumEvals = fromIntegral jsKeepNumEvals,
      jsHidden = not jsVisible,
      jsCheckInterval = fromIntegral jsCheckInterval,
      jsSchedulingShares = fromIntegral jsSchedulingShares,
      jsFetchErrorMsg = Nothing, -- TODO[sgillespie]
      jsForceEval = Nothing, -- TODO[sgillespie]
      jsStartTime = Nothing, -- TODO[sgillespie]
      jsType = type',
      jsFlake = jsFlake,
      jsEnableDynCmd = jsEnableDynRunCmd
    }
  where
    enabled' =
      case jsState of
        Api.JssDisabled -> 0
        Api.JssEnabled -> 1
        Api.JssOneShot -> 2
        Api.JssOneAtATime -> 3

    type' =
      case jsType of
        Api.JstLegacy -> 0
        Api.JstFlake -> 1
