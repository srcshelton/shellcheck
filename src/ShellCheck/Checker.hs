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
{-# LANGUAGE TemplateHaskell #-}
module ShellCheck.Checker (checkScript, ShellCheck.Checker.runTests) where

import ShellCheck.Analyzer
import ShellCheck.ASTLib
import ShellCheck.Interface
import ShellCheck.Parser

import Debug.Trace -- DO NOT SUBMIT
import Data.Either
import Data.Functor
import Data.List
import Data.Maybe
import Data.Ord
import Control.Monad.Identity
import qualified Data.Map as Map
import qualified System.IO
import Prelude hiding (readFile)
import Control.Monad

import Test.QuickCheck.All
import Test.QuickCheck (conjoin, counterexample)

tokenToPosition startMap t = fromMaybe fail $ do
    span <- Map.lookup (tcId t) startMap
    return $ newPositionedComment {
        pcStartPos = fst span,
        pcEndPos = snd span,
        pcComment = tcComment t,
        pcFix = tcFix t
    }
  where
    fail = error "Internal shellcheck error: id doesn't exist. Please report!"

shellFromFilename filename = listToMaybe candidates
  where
    shellExtensions = [(".ksh", Ksh)
                      ,(".bsh", IrixBsh)
                      ,(".jsh", IrixBsh)
                      ,(".bash", Bash)
                      ,(".bats", Bash)
                      ,(".dash", Dash)
                      ,(".envrc", Bash)]
                      -- The `.sh` is too generic to determine the shell:
                      -- We fallback to Bash in this case and emit SC2148 if there is no shebang
    candidates =
        [sh | (ext,sh) <- shellExtensions, ext `isSuffixOf` filename]

checkScript :: Monad m => SystemInterface m -> CheckSpec -> m CheckResult
checkScript sys spec = do
    results <- checkScript (csScript spec)
    return emptyCheckResult {
        crFilename = csFilename spec,
        crComments = results
    }
  where
    checkScript contents = do
        result <- parseScript sys newParseSpec {
            psFilename = csFilename spec,
            psScript = contents,
            psCheckSourced = csCheckSourced spec,
            psIgnoreRC = csIgnoreRC spec,
            psShellTypeOverride = csShellTypeOverride spec,
            psShVariant = csShVariant spec
        }
        let parseMessages = prComments result
        let tokenPositions = prTokenPositions result
        let analysisSpec root =
                as {
                    asScript = root,
                    asShellType = csShellTypeOverride spec,
                    asFallbackShell = shellFromFilename $ csFilename spec,
                    asCheckSourced = csCheckSourced spec,
                    asExecutionMode = Executed,
                    asTokenPositions = tokenPositions,
                    asExtendedAnalysis = csExtendedAnalysis spec,
                    asOptionalChecks = getEnableDirectives root ++ csOptionalChecks spec,
                    asUsedDisableDirectives = prUsedDisableDirectives result
                } where as = newAnalysisSpec root
        let analysisMessages =
                maybe []
                    (arComments . analyzeScript . analysisSpec)
                        $ prRoot result
        let translator = tokenToPosition tokenPositions
        return . nub . sortMessages . filter shouldInclude $
            (parseMessages ++ map translator analysisMessages)

    shouldInclude pc =
            severity <= csMinSeverity spec &&
            case csIncludedWarnings spec of
                Nothing -> code `notElem` csExcludedWarnings spec
                Just includedWarnings -> code `elem` includedWarnings
        where
            code     = cCode (pcComment pc)
            severity = cSeverity (pcComment pc)

    sortMessages = sortOn order
    order pc =
        let pos = pcStartPos pc
            comment = pcComment pc in
        (posFile pos,
         posLine pos,
         posColumn pos,
         cSeverity comment,
         cCode comment,
         cMessage comment)
    getPosition = pcStartPos


getErrors sys spec =
    sort . map getCode . crComments $
        runIdentity (checkScript sys spec)
  where
    getCode = cCode . pcComment

check = checkWithIncludes []

checkWithSpec includes =
    getErrors (mockedSystemInterface includes)

checkWithIncludes includes src =
    checkWithSpec includes emptyCheckSpec {
        csScript = src,
        csExcludedWarnings = [2148]
    }

checkRecursive includes src =
    checkWithSpec includes emptyCheckSpec {
        csScript = src,
        csExcludedWarnings = [2148],
        csCheckSourced = True
    }

checkOptionIncludes includes src =
    checkWithSpec [] emptyCheckSpec {
        csScript = src,
        csIncludedWarnings = includes,
        csCheckSourced = True
    }

checkWithOption option src =
    checkWithSpec [] emptyCheckSpec {
        csScript = src,
        csExcludedWarnings = [2148],
        csOptionalChecks = [option]
    }

-- Exercise optional checks through the same parse/analyze/filter path used by
-- callers. The module-local example tests verify each implementation directly;
-- this additionally catches missing registration and accidental default enablement.
-- IRIX profiles deliberately enable their platform-specific safety check.
prop_optionalExamplesWorkThroughChecker = all checkOptional optionalChecks
  where
    checkOptional description =
        let name = cdName description
            positive = cdPositive description
            negative = cdNegative description
        in if name == "check-irix-wait-status"
            then checkWithOption name positive == check positive
                && checkWithOption name negative == check negative
            else length (checkWithOption name positive) > length (check positive)
                && checkWithOption name negative == check negative

prop_irixProfilesEnableSafetyChecksByDefault = conjoin
    [ counterexample "irix-sh did not enable SC2337 and SC2348" $
        all (`elem` checkIrix source) [2337, 2348]
    , counterexample "irix-ksh did not enable SC2337 and SC2348" $
        all (`elem` checkIrixKsh source) [2337, 2348]
    , counterexample "irix-dtksh did not enable SC2337" $
        2337 `elem` checkIrixDtksh source
    , counterexample "irix-dtksh unexpectedly enabled the /sbin wait-status check" $
        2348 `notElem` checkIrixDtksh source
    , counterexample "generic ksh unexpectedly enabled IRIX profile checks" $
        null $ intersect [2337, 2348] $ check genericSource
    ]
  where
    source = unlines
        [ "# shellcheck disable=SC2086"
        , "long & old=$!"
        , "short & newer=$!"
        , "wait \"$newer\""
        , "wait \"$old\""
        ]
    genericSource = "#!/bin/ksh\n" ++ source

prop_irixInheritsErrexitWithOptionalCheck = all checkProfile ["irix-sh", "irix-ksh", "irix-dtksh"]
  where
    checkProfile shell = null $ intersect [2310, 2311] $ checkWithOption
        "check-set-e-suppressed" ("# shellcheck shell=" ++ shell ++ "\n" ++ source)
    source = "set -e; probe(){ false; echo survived; }; value=`probe`; echo \"after:<$value>\""

prop_irixStillChecksConditionalErrexit = all checkProfile ["irix-sh", "irix-ksh", "irix-dtksh"]
  where
    checkProfile shell = [2310] == (intersect [2310, 2311] $ check
        ("# shellcheck shell=" ++ shell ++ " enable=check-set-e-suppressed\n" ++ source))
    source = "set -e; probe(){ false; echo survived; }; if probe; then echo after; fi"

prop_irixErrexitWorkaroundBecomesUnused = all checkProfile ["irix-sh", "irix-ksh", "irix-dtksh"]
  where
    checkProfile shell = [2337] == (intersect [2311, 2337] $ check
        ("# shellcheck shell=" ++ shell ++ " enable=check-set-e-suppressed\n" ++ source))
    source = "set -e\nf(){ :; }\n# shellcheck disable=SC2311\nx=`f`\necho \"$x\""

prop_forkOptionalsUseExpectedSeverity = all hasExpectedSeverity cases
  where
    hasExpectedSeverity (option, code, severity, source) =
        any matches $ commentsWithOption option source
      where
        matches positioned =
            let comment = pcComment positioned
            in cCode comment == code && cSeverity comment == severity
    cases =
        [ ("check-unused-suppressions", 2337, StyleC,
            "# shellcheck disable=SC2086\necho \"$var\"")
        , ("prefer-single-quotes", 2338, StyleC, "var=\"constant\"")
        , ("require-quoted-parameter-expansion-words", 2339, StyleC,
            "echo \"${var:-default}\"")
        , ("require-single-quoted-case-patterns", 2340, StyleC,
            "case $var in value*) echo yes;; esac")
        , ("prefer-env-shebangs", 2341, StyleC, "#!/bin/bash\ntrue")
        , ("require-shebang-space", 2342, StyleC, "#!/bin/sh\ntrue")
        , ("require-variable-quotes", 2343, StyleC, "[[ ${var} ]]")
        , ("check-unbound-variables", 2344, InfoC, "set -u; echo \"$var\"")
        , ("require-variable-declarations", 2351, StyleC, "value=1; echo \"$value\"")
        , ("check-function-tracing-status", 2352, InfoC,
            "f() { false; set +x; }; if f; then :; fi")
        , ("check-exit-trap-scope", 2354, WarningC,
            "#!/bin/bash\nf() { local value=inner; trap 'echo \"$value\"' EXIT; }; f")
        , ("check-exit-in-subshell", 2345, WarningC,
            "input | while read -r line; do exit 1; done")
        , ("check-irix-wait-status", 2348, WarningC,
            "# shellcheck shell=irix-sh\nlong & old=$!; short & newer=$!; wait \"$newer\"; wait \"$old\"")
        , ("require-final-case-terminator", 2346, StyleC,
            "case $var in value) echo yes; esac")
        , ("require-double-brackets", 2292, StyleC, "[ -e /etc/issue ]")
        , ("add-default-case", 2249, InfoC,
            "case $? in 0) echo 'Success';; esac")
        ]
    commentsWithOption option source =
        crComments $ runIdentity $ checkScript
            (mockedSystemInterface [])
            emptyCheckSpec {
                csScript = source,
                csExcludedWarnings = [2148],
                csOptionalChecks = [option]
            }

checkWithRc rc = getErrors
    (mockRcFile rc $ mockedSystemInterface [])

checkWithIncludesAndSourcePath includes mapper = getErrors
    (mockedSystemInterface includes) {
        siFindSource = mapper
    }

checkWithRcIncludesAndSourcePath rc includes mapper = getErrors
    (mockRcFile rc $ mockedSystemInterface includes) {
        siFindSource = mapper
    }

prop_findsParseIssue = check "echo \"$12\"" == [1037]

prop_commentDisablesParseIssue1 =
    null $ check "#shellcheck disable=SC1037\necho \"$12\""
prop_commentDisablesParseIssue2 =
    null $ check "#shellcheck disable=SC1037\n#lol\necho \"$12\""

prop_findsAnalysisIssue =
    check "echo $1" == [2086]
prop_commentDisablesAnalysisIssue1 =
    null $ check "#shellcheck disable=SC2086\necho $1"
prop_commentDisablesAnalysisIssue2 =
    null $ check "#shellcheck disable=SC2086\n#lol\necho $1"

checkUnusedSuppressions src =
    getErrors
        (mockedSystemInterface [])
        emptyCheckSpec {
            csScript = src,
            csExcludedWarnings = [2148],
            csOptionalChecks = ["check-unused-suppressions"]
        }

prop_findsUnusedAnalysisSuppression =
    [2337] == checkUnusedSuppressions "# shellcheck disable=SC2086\necho \"$1\""
prop_acceptsUsedAnalysisSuppression =
    null $ checkUnusedSuppressions "# shellcheck disable=SC2086\necho $1"
prop_acceptsUsedUnreachableHereDocSuppression =
    null $ checkUnusedSuppressions $ unlines
        [ "#!/bin/sh"
        , "exit 0"
        , "# shellcheck disable=SC2317"
        , ": <<'DATA'"
        , "help text"
        , "DATA"
        ]
prop_acceptsSuppressionConsultedDuringAnalysis =
    null $ checkUnusedSuppressions "# shellcheck disable=SC2120\nf() { echo \"$1\"; }; f"
prop_findsUnusedParseSuppression =
    [2337] == checkUnusedSuppressions "# shellcheck disable=SC1037\necho \"${12}\""
prop_acceptsUsedParseSuppression =
    null $ checkUnusedSuppressions "# shellcheck disable=SC1037\necho \"$12\""
prop_checksEachSuppressionIndividually =
    [2337] == checkUnusedSuppressions "# shellcheck disable=SC2086,SC2154\necho $1"
prop_fileDirectiveCanEnableUnusedSuppressionCheck =
    [2337] == check "# shellcheck enable=check-unused-suppressions disable=SC2086\necho \"$1\""
prop_doesNotReportRcSuppressionsAsUnused = null result
  where
    result = checkWithRc "enable=check-unused-suppressions\ndisable=2086" emptyCheckSpec {
        csScript = "#!/bin/sh\necho \"$1\"",
        csIgnoreRC = False
    }

optionalSuppressionCases =
    [ ("check-extra-masked-returns", 2312, "echo `false`", "value=`false`")
    , ("check-unbound-variables", 2344, "set -u; echo \"$missing\"", "set -u; echo \"${missing:-}\"")
    , ("check-exit-in-subshell", 2345, "exit 1 | cat", "exit 1")
    ]

optionalSuppressionResult shell enabled code source =
    getErrors (mockedSystemInterface []) emptyCheckSpec {
        csScript = "# shellcheck disable=SC" ++ show code ++ "\n" ++ source,
        csShellTypeOverride = Just shell,
        csIncludedWarnings = Just [2337],
        csOptionalChecks = enabled
    }

prop_preservesDisabledOptionalSuppressions = conjoin
    [ counterexample (show shell ++ ": " ++ option ++ " / " ++ source) $
        null $ optionalSuppressionResult shell [] code source
    | shell <- [IrixSh, IrixKsh]
    , (option, code, positive, negative) <- optionalSuppressionCases
    , source <- [positive, negative]
    ]

prop_checksEnabledOptionalSuppressions = conjoin
    [ counterexample (show shell ++ ": " ++ option) $
        null (optionalSuppressionResult shell [option] code positive)
        && [2337] == optionalSuppressionResult shell [option] code negative
    | shell <- [IrixSh, IrixKsh]
    , (option, code, positive, negative) <- optionalSuppressionCases
    ]

prop_checksOptionalSuppressionsWithEnableAll = and
    [ null (optionalSuppressionResult shell ["all"] code positive)
        && [2337] == optionalSuppressionResult shell ["all"] code negative
    | shell <- [IrixSh, IrixKsh]
    , (_, code, positive, negative) <- optionalSuppressionCases
    ]

prop_optionalSuppressionRespectsEnableDirective =
    [2337] == checkOptionIncludes (Just [2337])
        "# shellcheck shell=irix-sh enable=check-unbound-variables\n# shellcheck disable=SC2344\nset -u; echo \"${missing:-}\""

prop_optionalSuppressionRespectsRc =
    [2337] == checkWithRc "enable=check-unbound-variables" emptyCheckSpec {
        csScript = "# shellcheck disable=SC2344\nset -u; echo \"${missing:-}\"",
        csShellTypeOverride = Just IrixKsh,
        csIncludedWarnings = Just [2337],
        csIgnoreRC = False
    }

prop_optionalSuppressionStillChecksProfileDefaults = all (\shell ->
    [2337] == optionalSuppressionResult shell [] 2348 "echo ok") [IrixSh, IrixKsh]

prop_optionalSuppressionDoesNotHideOrdinaryCodes = all (\shell ->
    [2337] == optionalSuppressionResult shell [] 2154 "echo ok") [IrixSh, IrixKsh]

prop_optionalSuppressionChecksMixedCodesSeparately =
    [2337] == checkOptionIncludes (Just [2337])
        "# shellcheck shell=irix-sh\n# shellcheck disable=SC2344,SC2086\necho ok"

prop_optionalSuppressionKeepsDisabledRange =
    null $ checkOptionIncludes (Just [2337])
        "# shellcheck shell=irix-sh\n# shellcheck disable=SC2310-SC2312\necho ok"

prop_optionalSuppressionRetainsDisableAllBehaviour =
    null $ checkOptionIncludes (Just [2337])
        "# shellcheck shell=irix-sh\n# shellcheck disable=all\necho ok"

prop_disabledOptionalMetadataIsHonoured = and
    [ null $ optionalSuppressionResult Bash ["check-unused-suppressions"] code "echo ok"
    | description <- optionalChecks
    , cdName description /= "check-unused-suppressions"
    , code <- cdOptionalCodes description
    ]

prop_optionalMetadataCoversNewDiagnostics = conjoin $ map checkDescription optionalChecks
  where
    checkDescription description = counterexample (cdName description ++ ": " ++ show extraCodes) $
        all (`elem` knownCodes) extraCodes
      where
        source = cdPositive description
        extraCodes = checkWithOption (cdName description) source \\ check source
        knownCodes = cdOptionalCodes description ++
            [2154 | cdName description == "check-unassigned-uppercase"]

checkIrix src =
    getErrors
        (mockedSystemInterface [])
        emptyCheckSpec {
            csScript = src,
            csExcludedWarnings = [2148],
            csShellTypeOverride = Just IrixSh
        }

checkIrixKsh src =
    getErrors
        (mockedSystemInterface [])
        emptyCheckSpec {
            csScript = src,
            csExcludedWarnings = [2148],
            csShellTypeOverride = Just IrixKsh
        }

checkIrixDtksh src =
    getErrors
        (mockedSystemInterface [])
        emptyCheckSpec {
            csScript = src,
            csExcludedWarnings = [2148],
            csShellTypeOverride = Just IrixDtksh
        }

prop_irixAcceptsBraceCase =
    null $ intersect [1072, 1073] $ checkIrix "case value {\nvalue) echo yes;;\n}"
prop_irixAcceptsTrailingCoprocess =
    2118 `notElem` checkIrix "print value |&\nread -p result"
prop_irixTracksReadPCoprocessVariable =
    2154 `notElem` checkIrix "print value |&\nread -p result\necho \"$result\""
prop_irixRejectsStderrPipeInterpretation =
    2118 `elem` checkIrix "print value |& sed 's/value/result/'"
prop_irixAcceptsDynamicUnaryOperator =
    null $ intersect [1072, 1073] $ checkIrix "LTEST=-d\n[ $LTEST path ]"
prop_irixAcceptsLowercaseLinkOperator =
    2058 `notElem` checkIrix "[ -l path ]"
prop_irixAcceptsVariableOutputFds =
    2261 `notElem` checkIrix "OUTPUTFD=1\ncommand >&$OUTPUTFD 2>&$OUTPUTFD"
prop_irixAcceptsElseIf =
    1075 `notElem` checkIrix "if false; then true; else if true; then echo nested; fi; fi"
prop_irixTracksSetAArrayAssignments =
    2154 `notElem` checkIrix "set -A values zero one two\necho \"${values[1]}\""
prop_irixAcceptsBareIntegerVariables =
    null $ intersect [2050, 2170] $ checkIrix "typeset -i index=1\n[ index -eq 1 ]"
prop_irixAcceptsLegacyBackticks =
    3068 `notElem` checkIrix "value=`echo hi`"
prop_irixRejectsMultiwordAssignment =
    2037 `elem` checkIrix "CSU=csu_off -C"
prop_irixAcceptsQuotedRegexClasses =
    1087 `notElem` checkIrix "egrep \"^$DSK[ \\t][ \\t]*$MOUNTPT[ \\t]\" file"
prop_irixAcceptsQuotedRegexLiteralTabs =
    1087 `notElem` checkIrix "egrep \"^$DSK[ \t][ \t]*$MOUNTPT[ \t]\" file"
prop_irixStillDiagnosesUnbracedArray =
    1087 `elem` checkIrix "echo \"$array[0]\""
prop_irixRejectsDollarCommandSubstitution =
    3068 `elem` checkIrix "value=$(echo hi)"
prop_irixRejectsArithmeticExpansion = conjoin
    [ counterexample source $ 3070 `elem` checkIrix source
    | source <- [ "line=1; line=$((line + 1)); echo \"$line\""
                , "line=1; line=\"$((line + 1))\"; echo \"$line\""
                , "consumed=0; text=abc; newline=1; consumed=$((consumed + ${#text} + newline))"
                , "echo $((1 + 1))"
                , "cat <<EOF\n$((1 + 1))\nEOF"
                ]]
prop_irixArithmeticExpansionIsProfileSpecific = conjoin
    [ counterexample shell $ 3070 `notElem` check
        ("# shellcheck shell=" ++ shell ++ "\necho $((1 + 1))")
    | shell <- ["sh", "bash", "dash", "ksh", "busybox", "irix-ksh", "irix-dtksh"]]
prop_irixAcceptsArithmeticCommands = conjoin
    [ counterexample source $ 3070 `notElem` checkIrix source
    | source <- [ "line=1; let \"line = line + 1\"; echo \"$line\""
                , "line=1; ((line = line + 1)); echo \"$line\""
                , "echo '$((1 + 1))'"
                , "cat <<'EOF'\n$((1 + 1))\nEOF"
                ]]
prop_irixArithmeticExpansionCanBeDisabled =
    3070 `notElem` checkIrix "# shellcheck disable=SC3070\necho $((1 + 1))"
prop_irixRejectsCStyleHexArithmetic = conjoin
    [ counterexample (shell ++ ": " ++ source) $ 3071 `elem` check
        ("# shellcheck shell=" ++ shell ++ "\n" ++ source)
    | shell <- ["irix-sh", "irix-ksh", "irix-dtksh"]
    , source <- [ "features=26; let '(features & ~0x1a) == 0'"
                , "let 'number = 0X1A'"
                , "((number = 0x1a))"
                , "((number = -0x1a))"
                , "echo ${values[0x1a]}"
                , "word=1a; let \"number = 0x${word}\""
                ]]
prop_irixHexArithmeticDoesNotAffectOtherShells = conjoin
    [ counterexample shell $ 3071 `notElem` check
        ("# shellcheck shell=" ++ shell ++ "\necho $((0x1a))")
    | shell <- ["sh", "bash", "dash", "ksh", "busybox"]]
prop_irixAcceptsBaseHashAndHexStrings = conjoin
    [ counterexample (shell ++ ": " ++ source) $ 3071 `notElem` check
        ("# shellcheck shell=" ++ shell ++ "\n" ++ source)
    | shell <- ["irix-sh", "irix-ksh", "irix-dtksh"]
    , source <- [ "let 'number = 16#1a'"
                , "word=ffffffff; let \"number = 16#${word}\""
                , "let '(features & ~26) == 0'"
                , "number=0x1a; print \"$number\""
                , "print '0x1a'"
                , "echo ${value:-0x1a} ${values[16#1a]}"
                ]]
prop_irixDecimalLetReferencesVariable =
    2034 `notElem` checkIrix "features=26; let '(features & ~26) == 0'"
prop_irixHexArithmeticCanBeDisabled =
    3071 `notElem` checkIrix "# shellcheck disable=SC3071\nlet 'number = 0x1a'"
prop_dynamicBracketCaseStyle = conjoin
    [ counterexample shell $ 2340 `notElem` checkWithOption
        "require-single-quoted-case-patterns"
        ("# shellcheck shell=" ++ shell ++ "\n" ++ source)
    | shell <- ["sh", "bash", "ksh", "irix-sh", "irix-ksh", "irix-dtksh"]
    , source <- [ "controls=a-z; case \"${text}\" in *[${controls}]*) :;; *) :;; esac"
                , "controls=`print '\\001-\\010\\013-\\037\\177'`; case \"${text}\" in *[${controls}]*) :;; *) :;; esac"
                ]]
prop_irixRejectsQuotedRemovalDelimiters =
    conjoin [counterexample (name ++ ": " ++ source) $ 3069 `elem` checkProfile source
            | (name, checkProfile) <- [("irix-sh", checkIrix), ("irix-ksh", checkIrixKsh)]
            , op <- ["%", "%%", "#", "##", ":-", ":=", ":+", ":?"]
            , delimiter <- [" ", "\t", "\n", ";", "|", "&", "(", ")", "<", ">"]
            , let source = "echo \"${args" ++ op ++ "\"$1" ++ delimiter ++ "\"*}\""]
prop_irixAcceptsValidRemovalQuotes =
    conjoin [counterexample (name ++ ": " ++ source) $ 3069 `notElem` checkProfile source
            | (name, checkProfile) <- [("irix-sh", checkIrix), ("irix-ksh", checkIrixKsh)]
            , source <- [ "echo ${args%%\"$1 \"*}"
                        , "echo \"${args%%\"$1\" *}\""
                        , "echo \"${m_opts%%\"$opt\"*}\""
                        , "echo \"${1%\"$arg\"}\""
                        , "echo ${m_opts%%\"$opt\"*} ${1%\"$arg\"}"
                        , "echo \"${var%\"a\\ b\"}\""
                        , "echo \"${var%\"a\\;b\"}\""
                        , "echo \"${var:-\"default\"}\""
                        , "echo \"${var:-a b}\""
                        , "echo \"${var%\"${suffix:-a b}\"}\""
                        , "echo \"${var%\"`echo a b`\"}\""
                        ]]
prop_irixRemovalDelimiterDiagnosticCanBeDisabled =
    3069 `notElem` checkIrix "# shellcheck disable=SC3069\necho \"${args%%\"$1 \"*}\""
prop_irixStillFindsConstantComparison =
    2050 `elem` checkIrix "[ \"FA_PORT\" = \"80\" ]"
prop_irixStillFindsConstantNullaryTest =
    2078 `elem` checkIrix "[ CONNTYPE ]"
prop_irixOmitsInapplicablePlatformAdvice =
    conjoin $ map checkCase cases
  where
    checkCase (code, source) =
        counterexample ("Unexpected SC" ++ show code ++ " for: " ++ source) $
            code `notElem` checkIrix source
    cases =
        [ (2001, "value=`echo \"$value\" | sed 's/a/b/g'`")
        , (2003, "value=`expr 3 + 2`")
        , (2009, "ps -ef | grep cron")
        , (2021, "tr '[a-z]' '[A-Z]'")
        , (2196, "egrep pattern file")
        , (2197, "fgrep pattern file")
        , (2197, "echo PCP | /usr/bin/fgrep -s PCP")
        , (2267, "xargs -i echo {}")
        , (2268, "[ x\"$value\" = x ]")
        ]
prop_irixAvoidsLetModernization =
    2219 `notElem` checkIrix "let value=value+1"
prop_irixRetainsApplicableStyleAdvice =
    conjoin $ map checkCase cases
  where
    checkCase (code, source) =
        counterexample ("Expected SC" ++ show code ++ " for: " ++ source) $
            code `elem` checkIrix source
    cases =
        [ (2000, "value=`echo \"$value\" | wc -c`")
        , (2004, "(( value = $value + 1 ))")
        , (2005, "echo `date`")
        , (2018, "tr 'a-z' 'A-Z'")
        , (2019, "tr 'a-z' 'A-Z'")
        , (2116, "command `echo value`")
        , (2126, "grep pattern file | wc -l")
        , (2129, "a >> file; b >> file; c >> file")
        , (2162, "read value")
        , (2181, "true; if [ $? -eq 0 ]; then echo yes; fi")
        , (2233, "if ( test -f file ); then echo yes; fi")
        , (2234, "( test -f file )")
        , (2235, "( test -f one && test -f two )")
        , (2308, "expr index \"$value\" abc")
        , (2331, "[ -a file ]")
        ]
prop_irixWorkaroundsBecomeUnused =
    [2337, 2337] == result
  where
    result = check "# shellcheck shell=irix-sh enable=check-unused-suppressions\n# shellcheck disable=SC1072,SC1073\ncase \"$1\" {\nvalue) true;;\n}"

prop_irixKshDirectiveSelectsDialect =
    3060 `elem` check "# shellcheck shell=irix-ksh\nvalue=abc\necho \"${value//a/b}\""
prop_irixKshAcceptsSupportedLanguage =
    null $ filter isLanguageError result
  where
    result = checkIrixKsh $ unlines
        [ "value=$(echo value)"
        , "number=$((1 + 1))"
        , "length=${#value}"
        , "(( number = number + 1 ))"
        , "let number=number+1"
        , "[[ -n $value ]]"
        , "read -r value"
        ]
    isLanguageError code = code >= 3000 && code < 4000
prop_irixKshRejectsStringReplacement =
    3060 `elem` checkIrixKsh "value=abc\necho \"${value//a/b}\""
prop_irixKshOmitsInapplicablePlatformAdvice =
    conjoin $ map checkCase cases
  where
    checkCase (code, source) =
        counterexample ("Unexpected SC" ++ show code ++ " for: " ++ source) $
            code `notElem` checkIrixKsh source
    cases =
        [ (2001, "value=$(echo \"$value\" | sed 's/a/b/g')")
        , (2009, "ps -ef | grep cron")
        , (2021, "tr '[a-z]' '[A-Z]'")
        , (2028, "echo '\\n'")
        , (2196, "egrep pattern file")
        , (2197, "fgrep pattern file")
        , (2197, "echo PCP | /usr/bin/fgrep -s PCP")
        , (2219, "let value=value+1")
        , (2268, "[ x\"$value\" = x ]")
        , (2268, "test \"x$value\" != x")
        , (2267, "xargs -i echo {}")
        , (2336, "cp -r source destination")
        ]
prop_irixKshRetainsApplicableDiagnostics =
    conjoin $ map checkCase cases
  where
    checkCase (code, source) =
        counterexample ("Expected SC" ++ show code ++ " for: " ++ source) $
            code `elem` checkIrixKsh source
    cases =
        [ (2003, "value=$(expr 3 + 2)")
        , (2050, "[ constant = constant ]")
        , (2086, "echo $value")
        , (2162, "read value")
        , (3060, "echo \"${value//a/b}\"")
        ]
prop_irixKshAcceptsIrixCoprocess =
    2118 `notElem` checkIrixKsh "print value |&\nread -p result"
prop_irixKshRejectsStderrPipeInterpretation =
    2118 `elem` checkIrixKsh "print value |& sed 's/value/result/'"

-- bsh and jsh use one language/analysis profile. Job-control defaults depend
-- on invocation/terminal state, not a different grammar.
checkIrixBsh src = getErrors (mockedSystemInterface []) emptyCheckSpec {
    csScript = src, csExcludedWarnings = [2148], csShellTypeOverride = Just IrixBsh
    }

prop_irixBourneSelection = conjoin
    [ counterexample name $ 3045 `elem` check ("# shellcheck shell=" ++ name ++ "\nread -r value")
    | name <- ["irix-bsh", "irix-jsh", "bsh", "jsh"] ]
prop_irixBourneShebangs = conjoin
    [ counterexample name $ 3045 `elem` check ("#!" ++ name ++ "\nread -r value")
    | name <- ["/bin/bsh", "/bin/jsh", "/sbin/bsh", "/usr/bin/env irix-jsh"] ]
prop_irixBourneUnsupported = conjoin
    [ counterexample source $ code `elem` checkIrixBsh source
    | (code, source) <-
        [ (3072, "x=$(echo value)")
        , (3073, "x=$((1 + 1))")
        , (3075, "x=abc; echo \"${#x}\"")
        , (3075, "x=abc; echo \"${x#a}\"")
        , (3075, "x=abc; echo \"${x%%c}\"")
        , (3074, "! false")
        , (3076, "export value=abc")
        , (3076, "readonly value=abc")
        , (3077, "[ -e /bin/bsh ]")
        , (3077, "[ a -nt b ]")
        , (3077, "test -S /bin/bsh")
        , (3044, "command echo value")
        , (3044, "print value")
        , (3045, "cd -L /")
        , (3045, "export -p")
        , (3045, "read -r value")
        , (3041, "set -o pipefail")
        , (3006, "((value=1))")
        , (3010, "[[ a = a ]]")
        , (3003, "echo $'hello'")
        , (3009, "echo {a,b}")
        ] ]
prop_irixBourneSupported = conjoin
    [ counterexample (source ++ " -> " ++ show (checkIrixBsh source)) $ null $ intersect [1072,1073,2000,2003,2006,2162,3003,3036,3037,3041,3044,3045,3075,3076] $ checkIrixBsh source
    | source <-
        [ "case value { value) echo yes;; }"
        , "f() { echo yes; }; f"
        , "value=`expr 1 + 1`; echo \"$value\""
        , "echo value | { read value; echo \"$value\"; }"
        , "value=abc; export value; readonly value"
        , "echo \"${value:-default} ${value:=assigned} ${value:+present}\""
        , "set -- a b; echo \"${#}\""
        , "echo -n value"
        , "set -m"
        , "value=abc; echo \"$value\" | wc -c"
        , "op=-f; [ \"$op\" /bin/bsh ]"
        ] ]
prop_irixBournePipelineScope =
    2031 `elem` checkIrixBsh "value=outer; echo inner | read value; echo \"$value\""
prop_irixBourneNoCoprocess =
    not (null (intersect [1072,1073,3029] $ checkIrixBsh "echo value |&"))
prop_irixBourneExtensions =
    shellFromFilename "script.bsh" == Just IrixBsh && shellFromFilename "script.jsh" == Just IrixBsh

checkShVariant variant src =
    getErrors
        (mockedSystemInterface [])
        emptyCheckSpec {
            csScript = src,
            csExcludedWarnings = [2148],
            csShVariant = Just variant
        }

prop_shVariantRemapsGenericShParser =
    null $ intersect [1072, 1073] $
        checkShVariant IrixSh "#!/bin/sh\ncase value {\nvalue) echo yes;;\n}"
prop_shVariantRemapsSbinSh =
    3068 `elem` checkShVariant IrixSh "#!/sbin/sh\nvalue=$(echo hi)"
prop_shVariantRemapsGenericShAnalyzer =
    3068 `elem` checkShVariant IrixSh "#!/bin/sh\nvalue=$(echo hi)"
prop_shVariantDoesNotRemapExplicitBash =
    3068 `notElem` checkShVariant IrixSh "#!/bin/bash\nvalue=$(echo hi)"
prop_shellDirectiveOverridesShVariant =
    3068 `notElem` checkShVariant IrixSh
        "#!/bin/sh\n# shellcheck shell=bash\nvalue=$(echo hi)"
prop_rcCanSetShVariant =
    3068 `elem` checkWithRc "sh-variant=irix-sh" emptyCheckSpec {
        csScript = "#!/bin/sh\nvalue=$(echo hi)"
    }
prop_shVariantPreservesShebangChecks =
    2239 `elem` checkShVariant IrixSh "#!sh\ntrue"

prop_optionDisablesIssue1 =
    null $ getErrors
                (mockedSystemInterface [])
                emptyCheckSpec {
                    csScript = "echo $1",
                    csExcludedWarnings = [2148, 2086]
                }

prop_optionDisablesIssue2 =
    null $ getErrors
                (mockedSystemInterface [])
                emptyCheckSpec {
                    csScript = "echo \"$10\"",
                    csExcludedWarnings = [2148, 1037]
                }

prop_wontParseBadShell =
    [1071] == check "#!/usr/bin/python\ntrue $1\n"

prop_optionDisablesBadShebang =
    null $ getErrors
                (mockedSystemInterface [])
                emptyCheckSpec {
                    csScript = "#!/usr/bin/python\ntrue\n",
                    csShellTypeOverride = Just Sh
                }

prop_annotationDisablesBadShebang =
    null $ check "#!/usr/bin/python\n# shellcheck shell=sh\ntrue\n"


prop_canParseDevNull =
    null $ check "source /dev/null"

prop_failsWhenNotSourcing =
    [1091, 2154] == check "source lol; echo \"$bar\""

prop_worksWhenSourcing =
    null $ checkWithIncludes [("lib", "bar=1")] "source lib; echo \"$bar\""

prop_worksWhenSourcingWithDashDash =
    null $ checkWithIncludes [("lib", "bar=1")] "source -- lib; echo \"$bar\""

prop_worksWhenSourcingWithDashP =
    null $ checkWithIncludes [("lib", "bar=1")] "source -p \"$MYPATH\" lib; echo \"$bar\""

prop_worksWhenDotting =
    null $ checkWithIncludes [("lib", "bar=1")] ". lib; echo \"$bar\""

-- FIXME: This should really be giving [1093], "recursively sourced"
prop_noInfiniteSourcing =
    null $ checkWithIncludes  [("lib", "source lib")] "source lib"

prop_canSourceBadSyntax =
    [1094, 2086] == checkWithIncludes [("lib", "for f; do")] "source lib; echo $1"

prop_cantSourceDynamic =
    [1090] == checkWithIncludes [("lib", "")] ". \"$1\""

prop_cantSourceDynamic2 =
    [1090] == checkWithIncludes [("lib", "")] "source ~/foo"

prop_canStripPrefixAndSource =
    null $ checkWithIncludes [("./lib", "")] "source \"$MYDIR/lib\""

prop_canStripPrefixAndSource2 =
    null $ checkWithIncludes [("./utils.sh", "")] "source \"$(dirname \"${BASH_SOURCE[0]}\")/utils.sh\""

prop_canSourceDynamicWhenRedirected =
    null $ checkWithIncludes [("lib", "")] "#shellcheck source=lib\n. \"$1\""

prop_canRedirectWithSpaces =
    null $ checkWithIncludes [("my file", "")] "#shellcheck source=\"my file\"\n. \"$1\""

prop_recursiveAnalysis =
    [2086] == checkRecursive [("lib", "echo $1")] "source lib"

prop_recursiveParsing =
    [1037] == checkRecursive [("lib", "echo \"$10\"")] "source lib"

prop_nonRecursiveAnalysis =
    null $ checkWithIncludes [("lib", "echo $1")] "source lib"

prop_nonRecursiveParsing =
    null $ checkWithIncludes [("lib", "echo \"$10\"")] "source lib"

prop_sourceDirectiveDoesntFollowFile =
    null $ checkWithIncludes
                [("foo", "source bar"), ("bar", "baz=3")]
                "#shellcheck source=foo\n. \"$1\"; echo \"$baz\""

prop_filewideAnnotationBase = [2086] == check "#!/bin/sh\necho $1"
prop_filewideAnnotation1 = null $
    check "#!/bin/sh\n# shellcheck disable=2086\necho $1"
prop_filewideAnnotation2 = null $
    check "#!/bin/sh\n# shellcheck disable=2086\ntrue\necho $1"
prop_filewideAnnotation3 = null $
    check "#!/bin/sh\n#unrelated\n# shellcheck disable=2086\ntrue\necho $1"
prop_filewideAnnotation4 = null $
    check "#!/bin/sh\n# shellcheck disable=2086\n#unrelated\ntrue\necho $1"
prop_filewideAnnotation5 = null $
    check "#!/bin/sh\n\n\n\n#shellcheck disable=2086\ntrue\necho $1"
prop_filewideAnnotation6 = null $
    check "#shellcheck shell=sh\n#unrelated\n#shellcheck disable=2086\ntrue\necho $1"
prop_filewideAnnotation7 = null $
    check "#!/bin/sh\n# shellcheck disable=2086\n#unrelated\ntrue\necho $1"

prop_filewideAnnotationBase2 = [2086, 2181] == check "true\n[ $? == 0 ] && echo $1"
prop_filewideAnnotation8 = null $
    check "# Disable $? warning\n#shellcheck disable=SC2181\n# Disable quoting warning\n#shellcheck disable=2086\ntrue\n[ $? == 0 ] && echo $1"

prop_sourcePartOfOriginalScript = -- #1181: -x disabled posix warning for 'source'
    3046 `elem` checkWithIncludes [("./saywhat.sh", "echo foo")] "#!/bin/sh\nsource ./saywhat.sh"

prop_spinBug1413 = null $ check "fun() {\n# shellcheck disable=SC2188\n> /dev/null\n}\n"

prop_deducesTypeFromExtension = null result
  where
    result = checkWithSpec [] emptyCheckSpec {
        csFilename = "file.ksh",
        csScript = "(( 3.14 ))"
    }

prop_deducesTypeFromExtension2 = result == [2079]
  where
    result = checkWithSpec [] emptyCheckSpec {
        csFilename = "file.bash",
        csScript = "(( 3.14 ))"
    }

prop_deducesTypeFromEnvrcExtension = result == [2079]
  where
    result = checkWithSpec [] emptyCheckSpec {
        csFilename = ".envrc",
        csScript = "(( 3.14 ))"
    }

prop_canDisableShebangWarning = null $ result
  where
    result = checkWithSpec [] emptyCheckSpec {
        csFilename = "file.sh",
        csScript = "#shellcheck disable=SC2148\nfoo"
    }

prop_canDisableAllWarnings = result == [2086]
  where
    result = checkWithSpec [] emptyCheckSpec {
        csFilename = "file.sh",
        csScript = "#!/bin/sh\necho $1\n#shellcheck disable=all\necho `echo $1`"
    }

prop_canDisableParseErrors = null $ result
  where
    result = checkWithSpec [] emptyCheckSpec {
        csFilename = "file.sh",
        csScript = "#shellcheck disable=SC1073,SC1072,SC2148\n()"
    }

prop_shExtensionDoesntMatter = result == [2148]
  where
    result = checkWithSpec [] emptyCheckSpec {
        csFilename = "file.sh",
        csScript = "echo 'hello world'"
    }

prop_sourcedFileUsesOriginalShellExtension = result == [2079]
  where
    result = checkWithSpec [("file.ksh", "(( 3.14 ))")] emptyCheckSpec {
        csFilename = "file.bash",
        csScript = "source file.ksh",
        csCheckSourced = True
    }

prop_canEnableOptionalsWithSpec = result == [2244]
  where
    result = checkWithSpec [] emptyCheckSpec {
        csFilename = "file.sh",
        csScript = "#!/bin/sh\n[ \"$1\" ]",
        csOptionalChecks = ["avoid-nullary-conditions"]
    }

prop_optionIncludes1 =
    -- expect 2086, but not included, so nothing reported
    null $ checkOptionIncludes (Just [2080]) "#!/bin/sh\n var='a b'\n echo $var"

prop_optionIncludes2 =
    -- expect 2086, included, so it is reported
    [2086] == checkOptionIncludes (Just [2086]) "#!/bin/sh\n var='a b'\n echo $var"

prop_optionIncludes3 =
    -- expect 2086, no inclusions provided, so it is reported
    [2086] == checkOptionIncludes Nothing "#!/bin/sh\n var='a b'\n echo $var"

prop_optionIncludes4 =
    -- expect 2086 & 2154, only 2154 included, so only that's reported
    [2154] == checkOptionIncludes (Just [2154]) "#!/bin/sh\n var='a b'\n echo $var\n echo $bar"


prop_readsRcFile = null result
  where
    result = checkWithRc "disable=2086" emptyCheckSpec {
        csScript = "#!/bin/sh\necho $1",
        csIgnoreRC = False
    }

prop_canUseNoRC = result == [2086]
  where
    result = checkWithRc "disable=2086" emptyCheckSpec {
        csScript = "#!/bin/sh\necho $1",
        csIgnoreRC = True
    }

prop_NoRCWontLookAtFile = result == [2086]
  where
    result = checkWithRc (error "Fail") emptyCheckSpec {
        csScript = "#!/bin/sh\necho $1",
        csIgnoreRC = True
    }

prop_brokenRcGetsWarning = result == [1134, 2086]
  where
    result = checkWithRc "rofl" emptyCheckSpec {
        csScript = "#!/bin/sh\necho $1",
        csIgnoreRC = False
    }

prop_canEnableOptionalsWithRc = result == [2244]
  where
    result = checkWithRc "enable=avoid-nullary-conditions" emptyCheckSpec {
        csScript = "#!/bin/sh\n[ \"$1\" ]"
    }

prop_sourcePathRedirectsName = result == [2086]
  where
    f "dir/myscript" _ _ "lib" = return "foo/lib"
    result = checkWithIncludesAndSourcePath [("foo/lib", "echo $1")] f emptyCheckSpec {
        csScript = "#!/bin/bash\nsource lib",
        csFilename = "dir/myscript",
        csCheckSourced = True
    }

prop_sourcePathAddsAnnotation = result == [2086]
  where
    f "dir/myscript" _ ["mypath"] "lib" = return "foo/lib"
    result = checkWithIncludesAndSourcePath [("foo/lib", "echo $1")] f emptyCheckSpec {
        csScript = "#!/bin/bash\n# shellcheck source-path=mypath\nsource lib",
        csFilename = "dir/myscript",
        csCheckSourced = True
    }

prop_sourcePathWorksWithSpaces = result == [2086]
  where
    f "dir/myscript" _ ["my path"] "lib" = return "foo/lib"
    result = checkWithIncludesAndSourcePath [("foo/lib", "echo $1")] f emptyCheckSpec {
        csScript = "#!/bin/bash\n# shellcheck source-path='my path'\nsource lib",
        csFilename = "dir/myscript",
        csCheckSourced = True
    }

prop_sourcePathRedirectsDirective = result == [2086]
  where
    f "dir/myscript" _ _ "lib" = return "foo/lib"
    f _ _ _ _ = return "/dev/null"
    result = checkWithIncludesAndSourcePath [("foo/lib", "echo $1")] f emptyCheckSpec {
        csScript = "#!/bin/bash\n# shellcheck source=lib\nsource kittens",
        csFilename = "dir/myscript",
        csCheckSourced = True
    }

prop_rcCanAllowExternalSources = result == [2086]
  where
    f "dir/myscript" (Just True) _ "mylib" = return "resolved/mylib"
    f a b c d = error $ show ("Unexpected", a, b, c, d)
    result = checkWithRcIncludesAndSourcePath "external-sources=true" [("resolved/mylib", "echo $1")] f emptyCheckSpec {
        csScript = "#!/bin/bash\nsource mylib",
        csFilename = "dir/myscript",
        csCheckSourced = True
    }

prop_rcCanDenyExternalSources = result == [2086]
  where
    f "dir/myscript" (Just False) _ "mylib" = return "resolved/mylib"
    f a b c d = error $ show ("Unexpected", a, b, c, d)
    result = checkWithRcIncludesAndSourcePath "external-sources=false" [("resolved/mylib", "echo $1")] f emptyCheckSpec {
        csScript = "#!/bin/bash\nsource mylib",
        csFilename = "dir/myscript",
        csCheckSourced = True
    }

prop_rcCanLeaveExternalSourcesUnspecified = result == [2086]
  where
    f "dir/myscript" Nothing _ "mylib" = return "resolved/mylib"
    f a b c d = error $ show ("Unexpected", a, b, c, d)
    result = checkWithRcIncludesAndSourcePath "" [("resolved/mylib", "echo $1")] f emptyCheckSpec {
        csScript = "#!/bin/bash\nsource mylib",
        csFilename = "dir/myscript",
        csCheckSourced = True
    }

prop_fileCanDisableExternalSources = result == [2006, 2086]
  where
    f "dir/myscript" (Just True) _ "withExternal" = return "withExternal"
    f "dir/myscript" (Just False) _ "withoutExternal" = return "withoutExternal"
    f a b c d = error $ show ("Unexpected", a, b, c, d)
    result = checkWithRcIncludesAndSourcePath "external-sources=true" [("withExternal", "echo $1"), ("withoutExternal", "_=`foo`")] f emptyCheckSpec {
        csScript = "#!/bin/bash\ntrue\nsource withExternal\n# shellcheck external-sources=false\nsource withoutExternal",
        csFilename = "dir/myscript",
        csCheckSourced = True
    }

prop_fileCannotEnableExternalSources = result == [1144]
  where
    f "dir/myscript" Nothing _ "foo" = return "foo"
    f a b c d = error $ show ("Unexpected", a, b, c, d)
    result = checkWithRcIncludesAndSourcePath "" [("foo", "true")] f emptyCheckSpec {
        csScript = "#!/bin/bash\n# shellcheck external-sources=true\nsource foo",
        csFilename = "dir/myscript",
        csCheckSourced = True
    }

prop_fileCannotEnableExternalSources2 = result == [1144]
  where
    f "dir/myscript" (Just False) _ "foo" = return "foo"
    f a b c d = error $ show ("Unexpected", a, b, c, d)
    result = checkWithRcIncludesAndSourcePath "external-sources=false" [("foo", "true")] f emptyCheckSpec {
        csScript = "#!/bin/bash\n# shellcheck external-sources=true\nsource foo",
        csFilename = "dir/myscript",
        csCheckSourced = True
    }

prop_rcCanSuppressEarlyProblems1 = null result
  where
    result = checkWithRc "disable=1071" emptyCheckSpec {
        csScript = "#!/bin/zsh\necho $1"
    }

prop_rcCanSuppressEarlyProblems2 = null result
  where
    result = checkWithRc "disable=1104" emptyCheckSpec {
        csScript = "!/bin/bash\necho 'hello world'"
    }

prop_sourceWithHereDocWorks = null result
  where
    result = checkWithIncludes [("bar", "true\n")] "source bar << eof\nlol\neof"

prop_hereDocsAreParsedWithoutTrailingLinefeed = 1044 `elem` result
  where
    result = check "cat << eof"

prop_hereDocsWillHaveParsedIndices = null result
  where
    result = check "#!/bin/bash\nmy_array=(a b)\ncat <<EOF >> ./test\n $(( 1 + my_array[1] ))\nEOF"

prop_rcCanSuppressDfa = null result
  where
    result = checkWithRc "extended-analysis=false" emptyCheckSpec {
        csScript = "#!/bin/sh\nexit; foo;"
    }

prop_fileCanSuppressDfa = null $ traceShowId result
  where
    result = checkWithRc "" emptyCheckSpec {
        csScript = "#!/bin/sh\n# shellcheck extended-analysis=false\nexit; foo;"
    }

prop_fileWinsWhenSuppressingDfa1 = null result
  where
    result = checkWithRc "extended-analysis=true" emptyCheckSpec {
        csScript = "#!/bin/sh\n# shellcheck extended-analysis=false\nexit; foo;"
    }

prop_fileWinsWhenSuppressingDfa2 = result == [2317]
  where
    result = checkWithRc "extended-analysis=false" emptyCheckSpec {
        csScript = "#!/bin/sh\n# shellcheck extended-analysis=true\nexit; foo;"
    }

prop_flagWinsWhenSuppressingDfa1 = result == [2317]
  where
    result = checkWithRc "extended-analysis=false" emptyCheckSpec {
        csScript = "#!/bin/sh\n# shellcheck extended-analysis=false\nexit; foo;",
        csExtendedAnalysis = Just True
    }

prop_flagWinsWhenSuppressingDfa2 = null result
  where
    result = checkWithRc "extended-analysis=true" emptyCheckSpec {
        csScript = "#!/bin/sh\n# shellcheck extended-analysis=true\nexit; foo;",
        csExtendedAnalysis = Just False
    }

return []
runTests = $quickCheckAll
