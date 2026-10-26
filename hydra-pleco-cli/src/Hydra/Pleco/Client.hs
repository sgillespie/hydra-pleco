module Hydra.Pleco.Client
  ( -- * The Pleco API client monad
    PlecoClient (..),
    PlecoClientEnv (..),
    PlecoClientError (..),
    mkPlecoClientEnv,
    runPlecoClient,
    plecoClient,

    -- * Querying the Pleco API
    getHealth,
    getProject,
    listProjects,
    listJobsets,
    findJobset,
    listEvals,
    getEval,

    -- * Running the reference webhook server
    runEchoServer,

    -- * Pleco API interface types
    Api.HealthJSON,
    Api.Health (..),
    Api.Subscription (..),
    Api.JobsetEvent (..),
    Api.EventType (..),
    Api.Project (..),
    Api.ProjectId (..),
    Api.Jobset (..),
    Api.JobsetId (..),
    Api.JobsetName (..),
    Api.JobsetType (..),
    Api.Eval (..),
    Api.EvalId (..),

    -- * Formatting results
    ToTable (..),
    toTable,
    renderJson,
    renderPlain,
    renderTerminal,

    -- * Utilities
    JobsetSpec (..),
    parseJobsetSpec,
    renderJobsetSpec,

    -- * Re-exports
    BaseUrl (..),
    Servant.Scheme (..),
    Servant.parseBaseUrl,
    FromJSON,
    ToJSON,
    Aeson.encodePretty,
  ) where

import Hydra.Pleco.Api
  ( Eval,
    EvalId,
    Health,
    HydraApi,
    Jobset,
    JobsetName,
    Project,
    ProjectId,
  )
import Hydra.Pleco.Api qualified as Api
import Hydra.Pleco.Client.EchoServer (runEchoServer)
import Hydra.Pleco.Client.Formatting (ToTable (..), toTable, toTableFancy, toTablePlain)

import Control.Exception (throwIO)
import Data.Aeson (FromJSON, ToJSON)
import Data.Aeson.Encode.Pretty qualified as Aeson
import Data.Text qualified as Text
import Hydra.Pleco.Client.Errors (PlecoClientError (..), fromClientError)
import Network.HTTP.Client (defaultManagerSettings, newManager)
import Servant.Client (AsClientT, BaseUrl, ClientEnv, ClientM, (//), (/:))
import Servant.Client qualified as Servant
import Servant.Client.Generic (genericClientHoist)

-- | Client application monad stack
newtype PlecoClient a = PlecoClient {unPlecoClient :: ReaderT PlecoClientEnv ClientM a}
  deriving newtype
    ( Functor,
      Applicative,
      Monad,
      MonadReader PlecoClientEnv,
      MonadIO
    )

newtype PlecoClientEnv = PlecoClientEnv
  { pceClientEnv :: ClientEnv
  }

data JobsetSpec = JobsetSpec ProjectId JobsetName
  deriving stock (Eq, Ord, Show)

mkPlecoClientEnv :: BaseUrl -> IO PlecoClientEnv
mkPlecoClientEnv url = do
  manager <- newManager defaultManagerSettings
  pure $ PlecoClientEnv (Servant.mkClientEnv manager url)

runPlecoClient :: PlecoClientEnv -> PlecoClient a -> IO a
runPlecoClient env@PlecoClientEnv {..} action = do
  res <- Servant.runClientM (runReaderT (unPlecoClient action) env) pceClientEnv
  either
    (throwIO . fromClientError (Servant.baseUrl pceClientEnv))
    pure
    res

renderJson :: (ToJSON json) => json -> LByteString
renderJson = Aeson.encodePretty

renderPlain :: (ToTable a) => Maybe Text -> a -> Text
renderPlain = toTablePlain

renderTerminal :: (ToTable a) => Maybe Text -> a -> Text
renderTerminal = toTableFancy

parseJobsetSpec :: Text -> Either PlecoClientError JobsetSpec
parseJobsetSpec spec =
  case Text.splitOn ":" spec of
    [project, jobset] -> Right $ JobsetSpec (Api.ProjectId project) (Api.JobsetName jobset)
    _ -> Left $ PlecoJobsetParseError spec

renderJobsetSpec :: JobsetSpec -> Text
renderJobsetSpec (JobsetSpec prj js) = Api.unProjectId prj <> ":" <> Api.unJobsetName js

plecoClient :: HydraApi (AsClientT PlecoClient)
plecoClient = genericClientHoist hoistClientM

hoistClientM :: ClientM a -> PlecoClient a
hoistClientM = PlecoClient . lift

getHealth :: PlecoClient Health
getHealth = plecoClient // Api.apiHealth

listProjects :: PlecoClient [Project]
listProjects = plecoClient // Api.apiProjects // Api.prjaList

getProject :: ProjectId -> PlecoClient Project
getProject = plecoClient // Api.apiProjects // Api.prjaGet

listJobsets :: ProjectId -> Maybe JobsetName -> PlecoClient [Jobset]
listJobsets = plecoClient // Api.apiProjects // Api.prjaJobsets

findJobset :: JobsetSpec -> PlecoClient (Maybe Jobset)
findJobset (JobsetSpec projectId jobset) = do
  jobsets <- plecoClient // Api.apiProjects // Api.prjaJobsets /: projectId /: Just jobset
  pure (listToMaybe jobsets)

listEvals :: JobsetSpec -> PlecoClient [Eval]
listEvals jobset = do
  jobset' <- findJobset jobset
  allEvals <- maybe (pure []) getEvals jobset'
  pure (filter Api.evHasNewBuilds allEvals)
  where
    getEvals :: Api.Jobset -> PlecoClient [Eval]
    getEvals Api.Jobset {jsId} = plecoClient // Api.apiJobsets // Api.jsaEvals /: jsId

getEval :: EvalId -> PlecoClient Eval
getEval = plecoClient // Api.apiEvals // Api.evaGet
