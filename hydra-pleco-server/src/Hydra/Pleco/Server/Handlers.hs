module Hydra.Pleco.Server.Handlers
  ( evalsHandler,
    listEvalsHandler,
    jobsetsHandler,
    listJobsetsHandler,
    projectsHandler,
    Webhook.webhooksHandler,
    Webhook.webhooksSubscribeHandler,
    Webhook.watchHydraEvents,
  ) where

import Hydra.Pleco.Server.Handlers.Evals (evalsHandler, listEvalsHandler)
import Hydra.Pleco.Server.Handlers.Jobsets (jobsetsHandler, listJobsetsHandler)
import Hydra.Pleco.Server.Handlers.Projects (projectsHandler)
import Hydra.Pleco.Server.Handlers.Webhook qualified as Webhook
