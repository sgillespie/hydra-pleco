module Hydra.Pleco.Api.Build
  ( Build (..),
    BuildId (..),
    BuildStatus (..),
  ) where

import Data.Aeson (FromJSON, ToJSON, (.:), (.=))
import Data.Aeson qualified as Aeson
import Data.HashMap.Strict.InsOrd.Compat qualified as InsOrd
import Data.OpenApi (ToParamSchema, ToSchema (..))
import Data.OpenApi qualified as OpenApi
import Optics ((.~), (?~))
import Servant.API (ToHttpApiData, FromHttpApiData)

data Build = Build
  { bldId :: BuildId,
    bldJob :: Text,
    bldFinishTime :: Maybe Int,
    bldPackageName :: Maybe Text,
    bldSystem :: Text,
    bldDrvPath :: FilePath,
    bldStatus :: BuildStatus
  }
  deriving stock (Eq, Show, Generic)

newtype BuildId = BuildId {unBuildId :: Int}
  deriving stock (Eq, Generic, Ord, Show)
  deriving newtype
    ( ToJSON,
      FromJSON,
      FromHttpApiData,
      ToHttpApiData,
      ToParamSchema,
      ToSchema
    )

data BuildStatus
  = BuildSucceeded
  | BuildFailed
  | BuildDepFailed
  | BuildAborted
  | BuildCancelled
  | BuildFailedWithOutput
  | BuildTimedOut
  deriving stock (Bounded, Eq, Enum, Show, Generic)

instance ToJSON Build where
  toJSON Build {..} =
    Aeson.object
      [ "id" .= bldId,
        "job" .= bldJob,
        "finish_time" .= bldFinishTime,
        "package_name" .= bldPackageName,
        "system" .= bldSystem,
        "drv_path" .= bldDrvPath,
        "status" .= bldStatus
      ]
  toEncoding Build {..} =
    Aeson.pairs $
      "id" .= bldId
        <> "job" .= bldJob
        <> "finish_time" .= bldFinishTime
        <> "package_name" .= bldPackageName
        <> "system" .= bldSystem
        <> "drv_path" .= bldDrvPath
        <> "status" .= bldStatus

instance FromJSON Build where
  parseJSON = Aeson.withObject "Build" $ \val -> do
    id' <- val .: "id"
    job <- val .: "job"
    finishedAt <- val .: "finish_time"
    package <- val .: "package_name"
    system <- val .: "system"
    drvPath <- val .: "drv_path"
    status <- val .: "status"

    pure
      Build
        { bldId = id',
          bldJob = job,
          bldFinishTime = finishedAt,
          bldPackageName = package,
          bldSystem = system,
          bldDrvPath = drvPath,
          bldStatus = status
        }

instance ToSchema Build where
  declareNamedSchema _ = do
    statusSchema <- OpenApi.declareSchemaRef @BuildStatus Proxy

    let properties =
          InsOrd.fromList
            [ ("id", OpenApi.toSchemaRef @BuildId Proxy),
              ("job", OpenApi.toSchemaRef @Text Proxy),
              ("finish_time", OpenApi.toSchemaRef @Int Proxy),
              ("package_name", OpenApi.toSchemaRef @Text Proxy),
              ("system", OpenApi.toSchemaRef @Text Proxy),
              ("drv_path", OpenApi.toSchemaRef @FilePath Proxy),
              ("status", statusSchema)
            ]
        required =
          [ "id",
            "job",
            "system",
            "drv_path",
            "status"
          ]

    pure $
      OpenApi.NamedSchema (Just "Build") $
        mempty
          & #properties .~ properties
          & #required .~ required
          & #type ?~ OpenApi.OpenApiObject

instance ToJSON BuildStatus where
  toJSON BuildSucceeded = "SUCCEEDED"
  toJSON BuildFailed = "FAILED"
  toJSON BuildDepFailed = "DEPENDENCY_FAILED"
  toJSON BuildAborted = "ABORTED"
  toJSON BuildCancelled = "CANCELLED"
  toJSON BuildFailedWithOutput = "FAILED_WITH_OUTPUT"
  toJSON BuildTimedOut = "TIMED_OUT"

instance FromJSON BuildStatus where
  parseJSON = Aeson.withText "BuildStatus" $ \case
    "SUCCEEDED" -> pure BuildSucceeded
    "FAILED" -> pure BuildFailed
    "DEPENDENCY_FAILED" -> pure BuildDepFailed
    "ABORTED" -> pure BuildAborted
    "CANCELLED" -> pure BuildCancelled
    "FAILED_WITH_OUTPUT" -> pure BuildFailedWithOutput
    "TIMED_OUT" -> pure BuildTimedOut
    e -> fail (toString e)

instance ToSchema BuildStatus where
  declareNamedSchema _ =
    pure $
      OpenApi.NamedSchema (Just "BuildStatus") $
        mempty
          & #enum ?~ map Aeson.toJSON (universe @BuildStatus)
          & #type ?~ OpenApi.OpenApiString
