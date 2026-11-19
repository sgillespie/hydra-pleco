module Hydra.Pleco.Server.Handlers
  ( projectsHandler,
    jobsetsHandler,
    evalsHandler,
    buildsHandler,
    Webhook.webhooksHandler,
    Webhook.webhooksSubscribeHandler,
    Webhook.watchHydraEvents,
  ) where

import Hydra.Pleco.Server.Handlers.Builds (buildsHandler)
import Hydra.Pleco.Server.Handlers.Evals (evalsHandler)
import Hydra.Pleco.Server.Handlers.Jobsets (jobsetsHandler)
import Hydra.Pleco.Server.Handlers.Projects (projectsHandler)
import Hydra.Pleco.Server.Handlers.Webhook qualified as Webhook
