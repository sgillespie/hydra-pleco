module Hydra.Pleco.Server.Handlers.Jobsets
  ( jobsetsHandler,
    listJobsetsHandler,
  ) where

import Hydra.Pleco.Api (Jobset (..), JobsetId (..), JobsetName, JobsetsApi (..), ProjectId (..), unJobsetName)
import Hydra.Pleco.Server.DB (jobsetById, runSession, statement)
import Hydra.Pleco.Server.DB qualified as DB
import Hydra.Pleco.Server.Handlers.Evals (listEvalsHandler)
import Hydra.Pleco.Server.Handlers.Jobsets.DB (fromJobset)
import Hydra.Pleco.Server.Monad (PlecoServerEnv (..), PlecoServerT)

import Hydra.Pleco.Server.Error (noSuchJobsetError, noSuchProjectError)
import Servant (Handler, NamedRoutes, ServerT, throwError)

jobsetsHandler :: ServerT (NamedRoutes JobsetsApi) (PlecoServerT Handler)
jobsetsHandler =
  JobsetsApi
    { jsaGet = getJobsetHandler,
      jsaEvals = listEvalsHandler
    }

listJobsetsHandler :: ProjectId -> Maybe JobsetName -> PlecoServerT Handler [Jobset]
listJobsetsHandler project@(ProjectId prjName) jobset = do
  pool <- asks pseDbPool

  -- Select the query to run; If the jobset name was specified, filter on both project and
  -- jobset name, otherwise filter only on project.
  let stmt =
        maybe
          (DB.jobsetsByProject prjName)
          (DB.jobsetsByProjectAndName prjName . unJobsetName)
          jobset

  -- Look up the project, then the jobset. If project does not exist, the result is
  -- 'Nothing', otherwise it's 'Just jobsets'
  jobsets <- runSession pool . runMaybeT $ do
    _ <- MaybeT $ statement () (DB.projectByName prjName)
    lift $ statement () stmt

  maybe
    (throwError $ noSuchProjectError project)
    (pure . map fromJobset)
    jobsets

getJobsetHandler :: JobsetId -> PlecoServerT Handler Jobset
getJobsetHandler jobset@(JobsetId jobsetId) = do
  pool <- asks pseDbPool
  dbJobset <-
    runSession pool . statement () $
      jobsetById (DB.JobsetId $ fromIntegral jobsetId)

  maybe
    (throwError $ noSuchJobsetError jobset)
    (pure . fromJobset)
    dbJobset
