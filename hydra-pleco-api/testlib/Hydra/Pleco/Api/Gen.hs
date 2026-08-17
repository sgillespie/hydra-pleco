module Hydra.Pleco.Api.Gen
  ( health,
    subscription,
    jobsetEvent,
    eventType,
  ) where

import Hydra.Pleco.Api
  ( EventType (..),
    Health (..),
    Jobset (..),
    JobsetEvent (..),
    Project (..),
    Subscription (..),
  )

import Hedgehog (Gen)
import Hedgehog.Gen qualified as Gen
import Hedgehog.Range qualified as Range

health :: Gen Health
health = Health <$> Gen.element ["pass", "fail", "warn"]

subscription :: Gen Subscription
subscription = Subscription <$> Gen.text len chars
  where
    -- maximum length of URL is essentially 2048
    len = Range.linear 0 2048
    -- latin1 should cover any URL-encoded string
    chars = Gen.latin1

jobsetEvent :: Gen JobsetEvent
jobsetEvent = do
  eventType' <- eventType
  project' <- project
  jobset' <- jobset

  pure
    JobsetEvent
      { jeEventType = eventType',
        jeProject = project',
        jeJobset = jobset'
      }

eventType :: Gen EventType
eventType =
  Gen.element
    [ EvalStarted,
      EvalAdded,
      EvalCached,
      EvalFailed,
      BuildQueued,
      CachedBuildQueued,
      BuildStarted,
      BuildFinished,
      CachedBuildFinished
    ]

project :: Gen Project
project = Project <$> genTitle

jobset :: Gen Jobset
jobset = Jobset <$> genTitle

genTitle :: Gen Text
genTitle = Gen.text (Range.linear 0 255) Gen.unicode
