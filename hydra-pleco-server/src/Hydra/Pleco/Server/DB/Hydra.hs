module Hydra.Pleco.Server.DB.Hydra
  ( Project (..),
    Jobset (..),
    JobsetId (..),
    JobsetEval (..),
    JobsetEvalId (..),
    HydraNotification (..),
    projectSchema,
    jobsetSchema,
    jobsetEvalSchema,
    eachProject,
    projectByName,
    jobsetById,
    jobsetsByProject,
    jobsetsByProjectAndName,
    jobsetEvalById,
    jobsetEvalsByJobset,
    hydraNotifyChannels,
    parseHydraNotification,
    renderHydraNotification,
  ) where

import Data.Text qualified as Text
import Hasql.Statement (Statement)
import Hydra.Pleco.Server.Error (PlecoServerError (..))
import Rel8
  ( Column,
    DBEq,
    DBType,
    Name,
    Rel8able,
    Result,
    TableSchema,
    (&&.),
    (==.),
  )
import Rel8 qualified

data Project f = Project
  { prjName :: Column f Text,
    prjDisplayName :: Column f Text,
    prjDescription :: Column f (Maybe Text),
    prjEnabled :: Column f Bool,
    prjHidden :: Column f Bool,
    prjOwner :: Column f Text,
    prjHomepage :: Column f (Maybe Text),
    prjDeclFile :: Column f (Maybe Text),
    prjDeclType :: Column f (Maybe Text),
    prjEnableDynCmd :: Column f Bool
  }
  deriving stock (Generic)
  deriving anyclass (Rel8able)

deriving stock instance (f ~ Result) => Eq (Project f)
deriving stock instance (f ~ Result) => Show (Project f)

data Jobset f = Jobset
  { jsName :: Column f Text,
    jsId :: Column f JobsetId,
    jsProject :: Column f Text,
    jsDescription :: Column f (Maybe Text),
    jsNixExprInput :: Column f (Maybe Text),
    jsNixExprPath :: Column f (Maybe Text),
    jsErrorMsg :: Column f (Maybe Text),
    jsErrorTime :: Column f (Maybe Int64),
    jsLastCheckedTime :: Column f (Maybe Int64),
    jsTriggerTime :: Column f (Maybe Int64),
    jsEnabled :: Column f Int64,
    jsEnableEmail :: Column f Bool,
    jsEmailOverride :: Column f Text,
    jsKeepNumEvals :: Column f Int64,
    jsHidden :: Column f Bool,
    jsCheckInterval :: Column f Int64,
    jsSchedulingShares :: Column f Int64,
    jsFetchErrorMsg :: Column f (Maybe Text),
    jsForceEval :: Column f (Maybe Bool),
    jsStartTime :: Column f (Maybe Int64),
    jsType :: Column f Int64,
    jsFlake :: Column f (Maybe Text),
    jsEnableDynCmd :: Column f Bool
  }
  deriving stock (Generic)
  deriving anyclass (Rel8able)

deriving stock instance Eq (Jobset Result)
deriving stock instance Show (Jobset Result)

projectSchema :: TableSchema (Project Name)
projectSchema =
  Rel8.TableSchema
    { name = "projects",
      columns = columnSchema
    }
  where
    columnSchema =
      Project
        { prjName = "name",
          prjDisplayName = "displayname",
          prjDescription = "description",
          prjEnabled = "enabled",
          prjHidden = "hidden",
          prjOwner = "owner",
          prjHomepage = "homepage",
          prjDeclFile = "declfile",
          prjDeclType = "decltype",
          prjEnableDynCmd = "enable_dynamic_run_command"
        }

jobsetSchema :: TableSchema (Jobset Name)
jobsetSchema = Rel8.TableSchema {name = "jobsets", columns = columnSchema}
  where
    columnSchema =
      Jobset
        { jsName = "name",
          jsId = "id",
          jsProject = "project",
          jsDescription = "description",
          jsNixExprInput = "nixexprinput",
          jsNixExprPath = "nixexprpath",
          jsErrorMsg = "errormsg",
          jsErrorTime = "errortime",
          jsLastCheckedTime = "lastcheckedtime",
          jsTriggerTime = "triggertime",
          jsEnabled = "enabled",
          jsEnableEmail = "enableemail",
          jsEmailOverride = "emailoverride",
          jsKeepNumEvals = "keepnr",
          jsHidden = "hidden",
          jsCheckInterval = "checkinterval",
          jsSchedulingShares = "schedulingshares",
          jsFetchErrorMsg = "fetcherrormsg",
          jsForceEval = "forceeval",
          jsStartTime = "starttime",
          jsType = "type",
          jsFlake = "flake",
          jsEnableDynCmd = "enable_dynamic_run_command"
        }

data JobsetEval f = JobsetEval
  { jseId :: Column f JobsetEvalId,
    jseJobsetId :: Column f JobsetId,
    jseTimestamp :: Column f Int64,
    jseCheckoutTime :: Column f Int64,
    jseEvalTime :: Column f Int64,
    jseHasNewBuilds :: Column f Int64,
    jseHash :: Column f Text,
    jseNumBuilds :: Column f (Maybe Int64),
    jseNumSucceeded :: Column f (Maybe Int64),
    jseFlake :: Column f (Maybe Text)
  }
  deriving stock (Generic)
  deriving anyclass (Rel8able)

deriving stock instance (f ~ Result) => Eq (JobsetEval f)
deriving stock instance (f ~ Result) => Show (JobsetEval f)

jobsetEvalSchema :: TableSchema (JobsetEval Name)
jobsetEvalSchema = Rel8.TableSchema {name = "jobsetevals", columns = columnSchema}
  where
    columnSchema =
      JobsetEval
        { jseId = "id",
          jseJobsetId = "jobset_id",
          jseTimestamp = "timestamp",
          jseCheckoutTime = "checkouttime",
          jseEvalTime = "evaltime",
          jseHasNewBuilds = "hasnewbuilds",
          jseHash = "hash",
          jseNumBuilds = "nrbuilds",
          jseNumSucceeded = "nrsucceeded",
          jseFlake = "flake"
        }

data HydraNotification
  = HydraEvalAdded JobsetId JobsetEvalId
  | HydraEvalStarted JobsetId
  | HydraEvalCached JobsetId JobsetEvalId
  | HydraEvalFailed JobsetId
  deriving stock (Eq, Show)

newtype JobsetId = JobsetId {unJobsetId :: Int64}
  deriving stock (Eq, Read, Show)
  deriving newtype (DBEq, DBType)

newtype JobsetEvalId = JobsetEvalId {unJobsetEvalId :: Int64}
  deriving stock (Eq, Read, Show)
  deriving newtype (DBEq, DBType)

eachProject :: Statement () [Project Result]
eachProject = Rel8.run $ Rel8.select (Rel8.each projectSchema)

projectByName :: Text -> Statement () (Maybe (Project Result))
projectByName name =
  Rel8.runMaybe $
    Rel8.select $ do
      projects <- Rel8.each projectSchema
      Rel8.where_ $ prjName projects ==. Rel8.lit name
      pure projects

jobsetById :: JobsetId -> Statement () (Jobset Result)
jobsetById jobsetId =
  Rel8.run1 $
    Rel8.select $ do
      jobsets <- Rel8.each jobsetSchema
      Rel8.where_ $ jsId jobsets ==. Rel8.lit jobsetId
      pure jobsets

jobsetsByProject :: Text -> Statement () [Jobset Result]
jobsetsByProject projectName =
  Rel8.run $
    Rel8.select $ do
      jobsets <- Rel8.each jobsetSchema
      Rel8.where_ $ jsProject jobsets ==. Rel8.lit projectName
      pure jobsets

jobsetsByProjectAndName :: Text -> Text -> Statement () [Jobset Result]
jobsetsByProjectAndName projectName jobsetName =
  Rel8.run $
    Rel8.select $ do
      jobsets <- Rel8.each jobsetSchema

      Rel8.where_ $
        jsProject jobsets ==. Rel8.lit projectName
          &&. jsName jobsets ==. Rel8.lit jobsetName

      pure jobsets

jobsetEvalById :: JobsetEvalId -> Statement () (JobsetEval Result)
jobsetEvalById evalId =
  Rel8.run1 $
    Rel8.select $ do
      evals <- Rel8.each jobsetEvalSchema
      Rel8.where_ $ jseId evals ==. Rel8.lit evalId

      pure evals

jobsetEvalsByJobset :: JobsetId -> Statement () [JobsetEval Result]
jobsetEvalsByJobset jobsetId =
  Rel8.run $
    Rel8.select $ do
      evals <- Rel8.each jobsetEvalSchema
      Rel8.where_ $ jseJobsetId evals ==. Rel8.lit jobsetId

      pure evals

hydraNotifyChannels :: [Text]
hydraNotifyChannels =
  [ "eval_added",
    "eval_started",
    "eval_cached",
    "eval_failed"
  ]

parseHydraNotification :: Text -> Text -> Either PlecoServerError HydraNotification
parseHydraNotification channel payload =
  case (channel, payload') of
    ("eval_added", [_, jobsetId, evalId]) ->
      HydraEvalAdded <$> readJobsetId' jobsetId <*> readEvalId' evalId
    ("eval_started", [_, jobsetId]) ->
      HydraEvalStarted <$> readJobsetId' jobsetId
    ("eval_cached", [_, jobsetId, evalId]) ->
      HydraEvalCached <$> readJobsetId' jobsetId <*> readEvalId' evalId
    ("eval_failed", [_, jobsetId]) ->
      HydraEvalFailed <$> readJobsetId' jobsetId
    _ ->
      Left . ServerParsingError $
        "Cannot parse event '" <> channel <> "' with payload: " <> payload
  where
    readJobsetId' :: Text -> Either PlecoServerError JobsetId
    readJobsetId' = fmap JobsetId . readEither'

    readEvalId' :: Text -> Either PlecoServerError JobsetEvalId
    readEvalId' = fmap JobsetEvalId . readEither'

    readEither' :: (Read a) => Text -> Either PlecoServerError a
    readEither' = first ServerParsingError . readEither . toString

    payload' = words payload

renderHydraNotification :: Text -> HydraNotification -> (Text, Text)
renderHydraNotification traceId' = \case
  HydraEvalAdded jobsetId evalId ->
    ("eval_added", mkPayload [renderJobsetId jobsetId, renderJobsetEvalId evalId])
  HydraEvalStarted jobsetId ->
    ("eval_started", mkPayload [renderJobsetId jobsetId])
  HydraEvalCached jobsetId evalId ->
    ("eval_cached", mkPayload [renderJobsetId jobsetId, renderJobsetEvalId evalId])
  HydraEvalFailed jobsetId ->
    ("eval_failed", mkPayload [renderJobsetId jobsetId])
  where
    mkPayload :: [Text] -> Text
    mkPayload = Text.intercalate "\t" . (traceId' :)

    renderJobsetId = show . unJobsetId
    renderJobsetEvalId = show . unJobsetEvalId
