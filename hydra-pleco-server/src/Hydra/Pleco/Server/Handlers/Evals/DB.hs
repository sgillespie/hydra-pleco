module Hydra.Pleco.Server.Handlers.Evals.DB
  ( fromEval,
    toEval,
  ) where

import Hydra.Pleco.Api qualified as Api
import Hydra.Pleco.Server.DB.Hydra qualified as Db
import Rel8 (Result)

fromEval :: Db.JobsetEval Result -> Api.Eval
fromEval Db.JobsetEval {..} =
  Api.Eval
    { evId = Api.EvalId $ fromIntegral (Db.unJobsetEvalId jseId),
      evJobsetId = Api.JobsetId $ fromIntegral (Db.unJobsetId jseJobsetId),
      evTimestamp = fromIntegral jseTimestamp,
      evCheckoutTime = fromIntegral jseCheckoutTime,
      evEvalTime = fromIntegral jseEvalTime,
      evHasNewBuilds = jseHasNewBuilds /= 0,
      evHash = jseHash,
      evNumBuilds = fromIntegral <$> jseNumBuilds,
      evNumSucceeded = fromIntegral <$> jseNumSucceeded,
      evFlake = jseFlake
    }

toEval :: Api.Eval -> Db.JobsetEval Result
toEval Api.Eval {..} =
  Db.JobsetEval
    { jseId = Db.JobsetEvalId $ fromIntegral (Api.unEvalId evId),
      jseJobsetId = Db.JobsetId $ fromIntegral (Api.unJobsetId evJobsetId),
      jseTimestamp = fromIntegral evTimestamp,
      jseCheckoutTime = fromIntegral evCheckoutTime,
      jseEvalTime = fromIntegral evEvalTime,
      jseHasNewBuilds = if evHasNewBuilds then 1 else 0,
      jseHash = evHash,
      jseNumBuilds = fromIntegral <$> evNumBuilds,
      jseNumSucceeded = fromIntegral <$> evNumSucceeded,
      jseFlake = evFlake
    }
