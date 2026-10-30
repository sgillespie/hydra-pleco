module Hydra.Pleco.Server.Gen
  ( project,
    jobsetEval,
    hydraNotification,
  ) where

import Hydra.Pleco.Api.Gen qualified as ApiGen
import Hydra.Pleco.Server.DB.Hydra
  ( HydraNotification (..),
    JobsetEval (..),
    JobsetEvalId (..),
    JobsetId (..),
    Project (..),
  )

import Hedgehog (Gen)
import Hedgehog.Gen qualified as Gen
import Hedgehog.Range qualified as Range
import Rel8 (Result)

project :: Gen (Project Result)
project = do
  name <- ApiGen.title
  displayName <- ApiGen.title
  description <- Gen.maybe ApiGen.title
  enabled <- Gen.bool
  hidden <- Gen.bool
  owner <- ApiGen.title
  homepage <- Gen.maybe ApiGen.url
  declFile <- Gen.maybe ApiGen.url
  declType <- Gen.maybe ApiGen.title
  enableDynCmd <- Gen.bool

  pure
    Project
      { prjName = name,
        prjDisplayName = displayName,
        prjDescription = description,
        prjEnabled = enabled,
        prjHidden = hidden,
        prjOwner = owner,
        prjHomepage = homepage,
        prjDeclFile = declFile,
        prjDeclType = declType,
        prjEnableDynCmd = enableDynCmd
      }

jobsetEval :: Gen (JobsetEval Result)
jobsetEval = do
  id' <- jobsetEvalId
  jobsetId' <- jobsetId
  timestamp <- genId
  checkoutTime <- genId
  evalTime <- genId
  -- Hydra stores hasnewbuilds as a 0/1 flag
  hasNewBuilds <- Gen.element [0, 1]
  hash' <- ApiGen.title
  numBuilds <- Gen.maybe genId
  numSucceeded <- Gen.maybe genId
  flake <- Gen.maybe ApiGen.url

  pure
    JobsetEval
      { jseId = id',
        jseJobsetId = jobsetId',
        jseTimestamp = timestamp,
        jseCheckoutTime = checkoutTime,
        jseEvalTime = evalTime,
        jseHasNewBuilds = hasNewBuilds,
        jseHash = hash',
        jseNumBuilds = numBuilds,
        jseNumSucceeded = numSucceeded,
        jseFlake = flake
      }

hydraNotification :: Gen HydraNotification
hydraNotification =
  Gen.choice
    [ HydraEvalAdded <$> jobsetId <*> jobsetEvalId,
      HydraEvalStarted <$> jobsetId,
      HydraEvalCached <$> jobsetId <*> jobsetEvalId,
      HydraEvalFailed <$> jobsetId
    ]

jobsetId :: Gen JobsetId
jobsetId = JobsetId <$> genId

jobsetEvalId :: Gen JobsetEvalId
jobsetEvalId = JobsetEvalId <$> genId

genId :: Gen Int64
genId = Gen.int64 (Range.linear 0 maxBound)
