{-
    Copyright 2012-2022 Vidar Holen

    This file is part of ShellCheck.
    https://www.shellcheck.net

    ShellCheck is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    ShellCheck is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.
-}
module ShellCheck.Analyzer (analyzeScript, ShellCheck.Analyzer.optionalChecks) where

import ShellCheck.Analytics
import ShellCheck.AST
import ShellCheck.ASTLib (getPath)
import ShellCheck.AnalyzerLib
import ShellCheck.Interface
import Control.Monad.Writer
import Data.List
import Data.Maybe
import Data.Monoid
import qualified Data.List.NonEmpty as NE
import qualified Data.Map as Map
import qualified ShellCheck.Checks.Commands
import qualified ShellCheck.Checks.ControlFlow
import qualified ShellCheck.Checks.Custom
import qualified ShellCheck.Checks.ShellSupport


-- TODO: Clean up the cruft this is layered on
analyzeScript :: AnalysisSpec -> AnalysisResult
analyzeScript spec = newAnalysisResult {
    arComments = filterByAnnotation spec params rawComments ++ unusedComments
}
  where
    params = makeParameters spec
    effectiveSpec = spec {
        asOptionalChecks = nub $
            asOptionalChecks spec ++ profileDefaultOptionalChecks (shellType params)
    }
    rawComments = nub $ runChecker params (checkers effectiveSpec params)
    unusedCheckEnabled =
        any (`elem` ["all", "check-unused-suppressions"])
            (asOptionalChecks effectiveSpec)
    unsuppressedSpec = effectiveSpec {
        asScript = stripDisableDirectives $ asScript effectiveSpec
    }
    unsuppressedParams = makeParameters unsuppressedSpec
    suppressionCandidates =
        if unusedCheckEnabled
        then nub $ runChecker unsuppressedParams (checkers unsuppressedSpec unsuppressedParams)
        else []
    usedDirectives =
        nub $ asUsedDisableDirectives spec ++ mapMaybe getSuppressingDirective suppressionCandidates
    unusedComments =
        if unusedCheckEnabled
        then mapMaybe unusedComment $ getDisableDirectives (asScript spec)
        else []

    profileDefaultOptionalChecks shell
        | shell `elem` [IrixSh, IrixKsh] =
            ["check-irix-wait-status", "check-unused-suppressions"]
        | shell == IrixDtksh =
            ["check-unused-suppressions"]
        | otherwise = []

    stripDisableDirectives = doTransform strip
      where
        strip (T_Annotation id annotations body) =
            case filter (not . isDisable) annotations of
                [] -> body
                remaining -> T_Annotation id remaining body
        strip token = token
        isDisable DisableComment {} = True
        isDisable DisableCommentWithId {} = True
        isDisable _ = False

    getSuppressingDirective note = findSuppressor $ NE.toList path
      where
        path = getPath (parentMap params) (T_Bang $ tcId note)
        code = cCode $ tcComment note
        findSuppressor [] = Nothing
        findSuppressor (T_Include {} : _) | not (asCheckSourced spec) = Nothing
        findSuppressor (T_Annotation _ annotations _ : rest) =
            case mapMaybe (suppressor code) annotations of
                sourceId:_ -> sourceId
                [] -> findSuppressor rest
        findSuppressor (_:rest) = findSuppressor rest
        suppressor code (DisableComment from to)
            | code >= from && code < to = Just Nothing
        suppressor code (DisableCommentWithId sourceId from to)
            | code >= from && code < to = Just $ Just sourceId
        suppressor _ _ = Nothing

    getDisableDirectives :: Token -> [(Id, Integer, Integer)]
    getDisableDirectives root = execWriter $ doAnalysis collect root
      where
        collect :: Token -> Writer [(Id, Integer, Integer)] ()
        collect (T_Annotation _ annotations _) =
            tell [(id, from, to) | DisableCommentWithId id from to <- annotations]
        collect _ = return ()

    unusedComment (id, from, to)
        | not (shouldCheckDirective id) = Nothing
        | id `elem` usedDirectives = Nothing
        | coversDisabledOptional from to = Nothing
        | otherwise = Just $ makeComment StyleC id 2337 (message from to)

    -- Not running an optional checker is not evidence that its suppression
    -- is obsolete. Use the effective options so profile defaults and `all`
    -- still receive the normal, scope-sensitive unused-suppression analysis.
    optionEnabled description = any (`elem` ["all", cdName description])
        (asOptionalChecks effectiveSpec)
    inactiveOptionalCodes =
        concatMap cdOptionalCodes (filter (not . optionEnabled) ShellCheck.Analyzer.optionalChecks)
        \\ concatMap cdOptionalCodes (filter optionEnabled ShellCheck.Analyzer.optionalChecks)
    coversDisabledOptional 0 1000000 = False -- `disable=all` covers this run.
    coversDisabledOptional from to =
        any (\code -> from <= code && code < to) inactiveOptionalCodes
    shouldCheckDirective id
        | asCheckSourced spec = True
        | otherwise =
            case (lookupFilename id, lookupFilename $ getId $ asScript spec) of
                (Just file, Just rootFile) -> file == rootFile
                _ -> True
    lookupFilename id = posFile . fst <$> Map.lookup id (asTokenPositions spec)
    message 0 1000000 =
        "This disable directive is unnecessary because it suppresses no diagnostics here."
    message from to
        | to == from + 1 =
            "This disable directive is unnecessary because SC" ++ show from ++ " is not reported here."
        | otherwise =
            "This disable directive is unnecessary because no diagnostics in its range are reported here."

checkers spec params = mconcat $ map ($ params) [
    ShellCheck.Analytics.checker spec,
    ShellCheck.Checks.Commands.checker spec,
    ShellCheck.Checks.ControlFlow.checker spec,
    ShellCheck.Checks.Custom.checker,
    ShellCheck.Checks.ShellSupport.checker
    ]

optionalChecks = unusedSuppressionCheck : mconcat [
        ShellCheck.Analytics.optionalChecks,
        ShellCheck.Checks.Commands.optionalChecks,
        ShellCheck.Checks.ControlFlow.optionalChecks
    ]
  where
    unusedSuppressionCheck = newCheckDescription {
        cdName = "check-unused-suppressions",
        cdOptionalCodes = [2337],
        cdDescription = "Suggest removing disable directives that suppress no diagnostics",
        cdPositive = "# shellcheck disable=SC2086\necho \"$var\"",
        cdNegative = "# shellcheck disable=SC2086\necho $var"
    }
