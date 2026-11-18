module Hydra.Pleco.Server.Handlers.Projects.DB
  ( fromProject,
    toProject,
  ) where

import Hydra.Pleco.Api qualified as Api
import Hydra.Pleco.Server.DB.Hydra (Project (..))
import Rel8 (Result)

fromProject :: Project Result -> Api.Project
fromProject Project {..} =
  Api.Project
    { prjId = Api.ProjectId prjName,
      prjEnabled = prjEnabled,
      prjVisible = not prjHidden,
      prjDisplayName = prjDisplayName,
      prjDescription = prjDescription,
      prjHomepage = prjHomepage,
      prjOwner = prjOwner,
      prjEnableDynRunCmd = prjEnableDynCmd,
      prjDeclSpecFile = toString <$> prjDeclFile,
      prjDeclInputType = prjDeclType
    }

toProject :: Api.Project -> Project Result
toProject Api.Project {..} =
  Project
    { prjName = Api.unProjectId prjId,
      prjDisplayName = prjDisplayName,
      prjDescription = prjDescription,
      prjEnabled = prjEnabled,
      prjHidden = not prjVisible,
      prjOwner = prjOwner,
      prjHomepage = prjHomepage,
      prjDeclFile = toText <$> prjDeclSpecFile,
      prjDeclType = prjDeclInputType,
      prjEnableDynCmd = prjEnableDynRunCmd
    }
