module Hydra.Pleco.Server.Handlers.Builds
  ( buildsHandler,
    listBuildsHandler,
  ) where

import Hydra.Pleco.Api (Build (..), BuildId, BuildStatus (..), BuildsApi (..), EvalId)
import Hydra.Pleco.Server.Monad (PlecoServerT)

import Servant (Handler, HasServer (..), NamedRoutes)

buildsHandler :: ServerT (NamedRoutes BuildsApi) (PlecoServerT Handler)
buildsHandler =
  BuildsApi
    { bdaGet = getBuildHandler
    }

listBuildsHandler :: EvalId -> PlecoServerT Handler [Build]
listBuildsHandler _ = pure []

getBuildHandler :: BuildId -> PlecoServerT Handler Build
getBuildHandler bldId =
  pure
    Build
      { bldId,
        bldJob = "",
        bldFinishTime = Nothing,
        bldPackageName = Nothing,
        bldSystem = "",
        bldDrvPath = "",
        bldStatus = BuildAborted
      }
