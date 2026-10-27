module Hydra.Pleco.Api.Gen
  ( problemDetails,
    health,
    subscription,
    jobsetEvent,
    eventType,
    project,
    projectId,
    jobset,
    jobsetName,
    jobsetId,
    jobsetState,
    jobsetType,
    eval,
    evalId,
    title,
    url,
    uriReference,
    status,
  ) where

import Hydra.Pleco.Api
  ( Eval (..),
    EvalId (..),
    EventType (..),
    Health (..),
    Jobset (..),
    JobsetEvent (..),
    JobsetId (..),
    JobsetName (..),
    JobsetState (..),
    JobsetType (..),
    ProblemDetails (..),
    Project (..),
    ProjectId (..),
    Subscription (Subscription),
  )

import Hedgehog (Gen)
import Hedgehog.Gen qualified as Gen
import Hedgehog.Range qualified as Range
import Network.HTTP.Types (Status (..))
import Network.URI (URI (..), nullURI)

problemDetails :: Gen ProblemDetails
problemDetails = do
  ty <- uriReference
  status' <- status
  title' <- title
  detail <- title

  pure
    ProblemDetails
      { pdType = ty,
        pdStatus = status',
        pdTitle = title',
        pdDetail = detail
      }

health :: Gen Health
health = Health <$> Gen.element ["pass", "fail", "warn"]

subscription :: Gen Subscription
subscription = Subscription <$> url

jobsetEvent :: Gen JobsetEvent
jobsetEvent = do
  eventType' <- eventType
  project' <- projectId
  jobsetName' <- jobsetName

  pure
    JobsetEvent
      { jeEventType = eventType',
        jeProject = project',
        jeJobset = jobsetName'
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
project = do
  name <- projectId
  enabled <- Gen.bool
  visible <- Gen.bool
  displayName <- title
  description <- Gen.maybe title
  homepage <- Gen.maybe url
  owner <- title
  enableDynRunCmd <- Gen.bool
  declSpecFile <- Gen.maybe (toString <$> url)
  declInputType <- Gen.maybe title

  pure
    Project
      { prjId = name,
        prjEnabled = enabled,
        prjVisible = visible,
        prjDisplayName = displayName,
        prjDescription = description,
        prjHomepage = homepage,
        prjOwner = owner,
        prjEnableDynRunCmd = enableDynRunCmd,
        prjDeclSpecFile = declSpecFile,
        prjDeclInputType = declInputType
      }

projectId :: Gen ProjectId
projectId = ProjectId <$> title

jobset :: Gen Jobset
jobset = do
  name' <- jobsetName
  project' <- projectId
  id' <- jobsetId
  state' <- jobsetState
  visible <- Gen.bool
  jsType <- jobsetType
  flake <- Gen.maybe url
  nixExprInput <- Gen.maybe url
  nixExprPath <- Gen.maybe title
  description <- Gen.maybe title
  checkInterval <- Gen.int (Range.linear 0 maxBound)
  schedulingShares <- Gen.int (Range.linear 0 21)
  enableDynRunCmd <- Gen.bool
  enableEmail <- Gen.bool
  emailOverride <- Gen.maybe title
  keepNumEvals <- Gen.int (Range.linear 0 50)
  lastCheckedTime <- Gen.maybe $ Gen.int (Range.linear 0 maxBound)
  lastEvalTime <- Gen.maybe $ Gen.int (Range.linear 0 maxBound)
  errorMsg <- Gen.maybe title
  errorTime <- Gen.maybe $ Gen.int (Range.linear 0 maxBound)

  pure
    Jobset
      { jsName = name',
        jsProject = project',
        jsId = id',
        jsState = state',
        jsVisible = visible,
        jsType = jsType,
        jsFlake = flake,
        jsNixExprInput = nixExprInput,
        jsNixExprPath = nixExprPath,
        jsDescription = description,
        jsCheckInterval = checkInterval,
        jsSchedulingShares = schedulingShares,
        jsEnableDynRunCmd = enableDynRunCmd,
        jsEnableEmail = enableEmail,
        jsEmailOverride = emailOverride,
        jsKeepNumEvals = keepNumEvals,
        jsLastCheckedTime = lastCheckedTime,
        jsLastEvalTime = lastEvalTime,
        jsErrorMsg = errorMsg,
        jsErrorTime = errorTime
      }

eval :: Gen Eval
eval = do
  id' <- evalId
  jobsetId' <- jobsetId
  timestamp <- Gen.int (Range.linear 0 maxBound)
  checkoutTime <- Gen.int (Range.linear 0 maxBound)
  evalTime <- Gen.int (Range.linear 0 maxBound)
  hasNewBuilds <- Gen.bool
  hash' <- title
  numBuilds <- Gen.maybe $ Gen.int (Range.linear 0 maxBound)
  numSucceeded <- Gen.maybe $ Gen.int (Range.linear 0 maxBound)
  flake <- Gen.maybe url

  pure
    Eval
      { evId = id',
        evJobsetId = jobsetId',
        evTimestamp = timestamp,
        evCheckoutTime = checkoutTime,
        evEvalTime = evalTime,
        evHasNewBuilds = hasNewBuilds,
        evHash = hash',
        evNumBuilds = numBuilds,
        evNumSucceeded = numSucceeded,
        evFlake = flake
      }

evalId :: Gen EvalId
evalId = EvalId <$> Gen.int (Range.linear 0 maxBound)

jobsetName :: Gen JobsetName
jobsetName = JobsetName <$> title

jobsetId :: Gen JobsetId
jobsetId = JobsetId <$> Gen.int (Range.linear 0 maxBound)

jobsetState :: Gen JobsetState
jobsetState = Gen.element [JssEnabled, JssDisabled, JssOneShot, JssOneAtATime]

jobsetType :: Gen JobsetType
jobsetType = Gen.element [JstFlake, JstLegacy]

title :: Gen Text
title = Gen.text (Range.linear 0 255) Gen.unicode

url :: Gen Text
url = Gen.text len chars
  where
    -- maximum length of URL is essentially 2048
    len = Range.linear 0 2048
    -- latin1 should cover any URL-encoded string
    chars = Gen.latin1

-- | A relative URI reference, eg '/problems/out-of-stock#read-timeout'
uriReference :: Gen URI
uriReference = do
  path <- Gen.list (Range.linear 1 3) segment
  fragment <- Gen.maybe segment

  pure
    nullURI
      { uriPath = concatMap ("/" <>) path,
        uriFragment = maybe "" ("#" <>) fragment
      }
  where
    segment = Gen.string (Range.linear 1 16) Gen.alphaNum

-- | An HTTP status, between 100 and 599
status :: Gen Status
status = Status <$> Gen.int (Range.linear 100 599) <*> (encodeUtf8 <$> title)
