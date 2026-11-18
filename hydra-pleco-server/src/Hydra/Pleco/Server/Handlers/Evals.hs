module Hydra.Pleco.Server.Handlers.Evals
  ( evalsHandler,
    listEvalsHandler,
  ) where

import Hydra.Pleco.Api (Eval (..), EvalId (..), EvalsApi (..), JobsetId (..))
import Hydra.Pleco.Server.DB qualified as DB
import Hydra.Pleco.Server.Handlers.Evals.DB (fromEval)
import Hydra.Pleco.Server.Monad (PlecoServerEnv (..), PlecoServerT)

import Hydra.Pleco.Server.Error (noSuchEvalError, noSuchJobsetError)
import Servant (Handler, NamedRoutes, ServerT, throwError)

evalsHandler :: ServerT (NamedRoutes EvalsApi) (PlecoServerT Handler)
evalsHandler =
  EvalsApi
    { evaGet = getEvalHandler
    }

listEvalsHandler :: JobsetId -> PlecoServerT Handler [Eval]
listEvalsHandler jobset@(JobsetId jobsetId) = do
  pool <- asks pseDbPool

  -- Look up the jobset, then its evals. If the jobset does not exist, the result is
  -- 'Nothing', otherwise it's 'Just evals'
  evals <- DB.runSession pool . runMaybeT $ do
    _ <- MaybeT $ DB.statement () (DB.jobsetById jobsetId')
    lift $ DB.statement () (DB.jobsetEvalsByJobset jobsetId')

  maybe
    (throwError $ noSuchJobsetError jobset)
    (pure . map fromEval)
    evals
  where
    jobsetId' = DB.JobsetId (fromIntegral jobsetId)

getEvalHandler :: EvalId -> PlecoServerT Handler Eval
getEvalHandler eval@(EvalId evalId) = do
  pool <- asks pseDbPool
  dbEval <-
    DB.runSession pool $
      DB.statement () (DB.jobsetEvalById evalId')

  maybe
    (throwError $ noSuchEvalError eval)
    (pure . fromEval)
    dbEval
  where
    evalId' = DB.JobsetEvalId (fromIntegral evalId)
