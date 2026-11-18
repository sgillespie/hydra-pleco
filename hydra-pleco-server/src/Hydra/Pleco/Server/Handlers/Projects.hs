module Hydra.Pleco.Server.Handlers.Projects
  ( projectsHandler,
  ) where

import Hydra.Pleco.Api (Project (..), ProjectId (..), ProjectsApi (..))
import Hydra.Pleco.Server.DB (eachProject, projectByName, runSession, statement)
import Hydra.Pleco.Server.Error (noSuchProjectError)
import Hydra.Pleco.Server.Handlers.Jobsets (listJobsetsHandler)
import Hydra.Pleco.Server.Handlers.Projects.DB (fromProject)
import Hydra.Pleco.Server.Monad (PlecoServerEnv (..), PlecoServerT)

import Servant (Handler, HasServer (..), NamedRoutes, throwError)

projectsHandler :: ServerT (NamedRoutes ProjectsApi) (PlecoServerT Handler)
projectsHandler =
  ProjectsApi
    { prjaList = listProjectsHandler,
      prjaGet = getProjectHandler,
      prjaJobsets = listJobsetsHandler
    }

listProjectsHandler :: PlecoServerT Handler [Project]
listProjectsHandler = do
  pool <- asks pseDbPool

  dbProjects <- runSession pool $ statement () eachProject
  pure $ map fromProject dbProjects

getProjectHandler :: ProjectId -> PlecoServerT Handler Project
getProjectHandler project = do
  pool <- asks pseDbPool

  dbProject <-
    runSession pool . statement () $
      projectByName (unProjectId project)

  maybe
    (throwError $ noSuchProjectError project)
    (pure . fromProject)
    dbProject
