{-# LANGUAGE TemplateHaskell #-}
module ShellCheck.Data where

import ShellCheck.Interface
import Data.List (isInfixOf, stripPrefix)
import Data.Version (showVersion)
import Test.QuickCheck.All (forAllProperties)
import Test.QuickCheck.Test (quickCheckWithResult, stdArgs, maxSuccess)


{-
If you are here because you saw an error about Paths_ShellCheck in this file,
simply comment out the import below and define the version as a constant string.

Instead of:

    import Paths_ShellCheck (version)
    shellcheckVersion = showVersion version

Use:

    -- import Paths_ShellCheck (version)
    shellcheckVersion = "kludge"

-}

import Paths_ShellCheck (version)
shellcheckVersion = toIrixVersion (showVersion version ++ "-irix.9")  -- VERSIONSTRING

-- Cabal package versions are numeric, so the fork suffix cannot live in
-- ShellCheck.cabal.  Release builds replace the argument above with their
-- exact git description; normal package builds retain the current fork release.
toIrixVersion versionString =
    case stripPrefix "v" versionString of
        Just unprefixed | hasIrixSuffix unprefixed -> unprefixed
        _ | hasIrixSuffix versionString -> versionString
          | otherwise -> versionString ++ "-irix"
  where
    hasIrixSuffix = isInfixOf "-irix"

internalVariables = [
    -- Generic
    "", "_", "rest", "REST",

    -- POSIX
    "CDPATH", "ENV", "FCEDIT", "HISTFILE", "HISTSIZE", "HOME", "IFS", "LANG",
    "LC_ALL", "LC_COLLATE", "LC_CTYPE", "LC_MESSAGES", "LC_MONETARY",
    "LC_NUMERIC", "LC_TIME", "MAIL", "MAILCHECK", "MAILPATH", "OLDPWD",
    "OPTARG", "OPTIND", "PATH", "PWD",

    -- Bash
    "BASH", "BASHOPTS", "BASHPID", "BASH_ALIASES", "BASH_ARGC",
    "BASH_ARGV", "BASH_ARGV0", "BASH_CMDS", "BASH_COMMAND",
    "BASH_EXECUTION_STRING", "BASH_LINENO", "BASH_LOADABLES_PATH",
    "BASH_REMATCH", "BASH_SOURCE", "BASH_SUBSHELL", "BASH_VERSINFO",
    "BASH_VERSION", "COMP_CWORD", "COMP_KEY", "COMP_LINE", "COMP_POINT",
    "COMP_TYPE", "COMP_WORDBREAKS", "COMP_WORDS", "COPROC", "DIRSTACK",
    "EPOCHREALTIME", "EPOCHSECONDS", "EUID", "FUNCNAME", "GROUPS", "HISTCMD",
    "HOSTNAME", "HOSTTYPE", "MACHTYPE", "MAPFILE", "OSTYPE", "PIPESTATUS",
    "RANDOM", "READLINE_ARGUMENT", "READLINE_LINE", "READLINE_MARK",
    "READLINE_POINT", "REPLY", "SECONDS", "SHELLOPTS", "SHLVL", "SRANDOM",
    "UID", "BASH_COMPAT", "BASH_ENV", "BASH_XTRACEFD", "CHILD_MAX", "COLUMNS",
    "COMPREPLY", "EMACS", "EXECIGNORE", "FIGNORE", "FUNCNEST", "GLOBIGNORE",
    "HISTCONTROL", "HISTFILESIZE", "HISTIGNORE", "HISTTIMEFORMAT", "HOSTFILE",
    "IGNOREEOF", "INPUTRC", "INSIDE_EMACS", "LINES", "OPTERR",
    "POSIXLY_CORRECT", "PROMPT_COMMAND", "PROMPT_DIRTRIM", "PS0", "PS1", "PS2",
    "PS3", "PS4", "SHELL", "TIMEFORMAT", "TMOUT", "BASH_MONOSECONDS",
    "BASH_TRAPSIG", "GLOBSORT", "auto_resume", "histchars",

    -- Other
    "USER", "TZ", "TERM", "LOGNAME", "LD_LIBRARY_PATH", "LANGUAGE", "DISPLAY",
    "HOSTNAME", "KRB5CCNAME", "LINENO", "PPID", "TMPDIR", "XAUTHORITY"

    -- Ksh
    , ".sh.version"

    -- shflags
    , "FLAGS_ARGC", "FLAGS_ARGV", "FLAGS_ERROR", "FLAGS_FALSE", "FLAGS_HELP",
    "FLAGS_PARENT", "FLAGS_RESERVED", "FLAGS_TRUE", "FLAGS_VERSION",
    "flags_error", "flags_return"

    -- Bats
    ,"stderr", "stderr_lines"
  ]

specialIntegerVariables = [
    "$", "?", "!", "#"
  ]

specialVariablesWithoutSpaces = "-" : specialIntegerVariables

variablesWithoutSpaces = specialVariablesWithoutSpaces ++ [
    "BASHPID", "BASH_ARGC", "BASH_LINENO", "BASH_SUBSHELL", "EUID",
    "EPOCHREALTIME", "EPOCHSECONDS", "LINENO", "OPTIND", "PPID", "RANDOM",
    "READLINE_ARGUMENT", "READLINE_MARK", "READLINE_POINT", "SECONDS",
    "SHELLOPTS", "SHLVL", "SRANDOM", "UID", "COLUMNS", "HISTFILESIZE",
    "HISTSIZE", "LINES", "BASH_MONOSECONDS", "BASH_TRAPSIG"

    -- shflags
    , "FLAGS_ERROR", "FLAGS_FALSE", "FLAGS_TRUE"
  ]

specialVariables = specialVariablesWithoutSpaces ++ ["@", "*"]

unbracedVariables = specialVariables ++ [
    "0", "1", "2", "3", "4", "5", "6", "7", "8", "9"
  ]

arrayVariables = [
    "BASH_ALIASES", "BASH_ARGC", "BASH_ARGV", "BASH_CMDS", "BASH_LINENO",
    "BASH_REMATCH", "BASH_SOURCE", "BASH_VERSINFO", "COMP_WORDS", "COPROC",
    "DIRSTACK", "FUNCNAME", "GROUPS", "MAPFILE", "PIPESTATUS", "COMPREPLY"
  ]

commonCommands = [
    "admin", "alias", "ar", "asa", "at", "awk", "basename", "batch",
    "bc", "bg", "break", "c99", "cal", "cat", "cd", "cflow", "chgrp",
    "chmod", "chown", "cksum", "cmp", "colon", "comm", "command",
    "compress", "continue", "cp", "crontab", "csplit", "ctags", "cut",
    "cxref", "date", "dd", "delta", "df", "diff", "dirname", "dot",
    "du", "echo", "ed", "env", "eval", "ex", "exec", "exit", "expand",
    "export", "expr", "fc", "fg", "file", "find", "fold", "fuser",
    "gencat", "get", "getconf", "getopts", "gettext", "grep", "hash",
    "head", "iconv", "ipcrm", "ipcs", "jobs", "join", "kill", "lex",
    "link", "ln", "locale", "localedef", "logger", "logname", "lp",
    "ls", "m4", "mailx", "make", "man", "mesg", "mkdir", "mkfifo",
    "more", "msgfmt", "mv", "newgrp", "ngettext", "nice", "nl", "nm",
    "nohup", "od", "paste", "patch", "pathchk", "pax", "pr", "printf",
    "prs", "ps", "pwd", "read", "readlink", "readonly", "realpath",
    "renice", "return", "rm", "rmdel", "rmdir", "sact", "sccs", "sed",
    "set", "sh", "shift", "sleep", "sort", "split", "strings", "strip",
    "stty", "tabs", "tail", "talk", "tee", "test", "time", "timeout",
    "times", "touch", "tput", "tr", "trap", "tsort", "tty", "type",
    "ulimit", "umask", "unalias", "uname", "uncompress", "unexpand",
    "unget", "uniq", "unlink", "unset", "uucp", "uudecode", "uuencode",
    "uustat", "uux", "val", "vi", "wait", "wc", "what", "who", "write",
    "xargs", "xgettext", "yacc", "zcat"
  ]

nonReadingCommands = [
    "alias", "basename", "bg", "cal", "cd", "chgrp", "chmod", "chown",
    "cp", "du", "echo", "export", "fg", "fuser", "getconf",
    "getopt", "getopts", "ipcrm", "ipcs", "jobs", "kill", "ln", "ls",
    "locale", "mv", "printf", "ps", "pwd", "readlink", "realpath",
    "renice", "rm", "rmdir", "set", "sleep", "touch", "trap", "ulimit",
    "unalias", "uname"
    ]

sampleWords = [
    "alpha", "bravo", "charlie", "delta", "echo", "foxtrot",
    "golf", "hotel", "india", "juliett", "kilo", "lima", "mike",
    "november", "oscar", "papa", "quebec", "romeo", "sierra",
    "tango", "uniform", "victor", "whiskey", "xray", "yankee",
    "zulu"
  ]

binaryTestOps = [
    "-nt", "-ot", "-ef", "==", "!=", "<=", ">=", "-eq", "-ne", "-lt", "-le",
    "-gt", "-ge", "=~", ">", "<", "=", "\\<", "\\>", "\\<=", "\\>="
  ]

arithmeticBinaryTestOps = [
    "-eq", "-ne", "-lt", "-le", "-gt", "-ge"
  ]

unaryTestOps = [
    "!", "-a", "-b", "-c", "-d", "-e", "-f", "-g", "-h", "-L", "-k", "-p",
    "-r", "-s", "-S", "-t", "-u", "-w", "-x", "-O", "-G", "-N", "-z", "-n",
    "-o", "-v", "-R"
  ]

shellForExecutable :: String -> Maybe Shell
shellForExecutable name =
    case name of
        "sh"    -> return Sh
        "bash"  -> return Bash
        "bats"  -> return Bash
        "busybox"  -> return BusyboxSh -- Used for directives and --shell=busybox
        "busybox sh"  -> return BusyboxSh
        "busybox ash"  -> return BusyboxSh
        "dash"  -> return Dash
        "ash"   -> return Dash -- There's also a warning for this.
        "ksh"   -> return Ksh
        "ksh88" -> return Ksh
        "ksh93" -> return Ksh
        "oksh"  -> return Ksh
        "bsh" -> return IrixBsh
        "jsh" -> return IrixBsh
        "irix-bsh" -> return IrixBsh
        "irix-jsh" -> return IrixBsh
        "irix-sh" -> return IrixSh
        "irix-ksh" -> return IrixKsh
        "dtksh" -> return IrixDtksh
        "irix-dtksh" -> return IrixDtksh
        _ -> Nothing

shellName :: Shell -> String
shellName shell =
    case shell of
        Sh -> "sh"
        Bash -> "bash"
        Dash -> "dash"
        Ksh -> "ksh"
        BusyboxSh -> "busybox"
        IrixBsh -> "irix-bsh"
        IrixSh -> "irix-sh"
        IrixKsh -> "irix-ksh"
        IrixDtksh -> "irix-dtksh"

isIrixPlatformShell IrixBsh = True
isIrixPlatformShell IrixSh = True
isIrixPlatformShell IrixKsh = True
isIrixPlatformShell IrixDtksh = True
isIrixPlatformShell _ = False

-- bsh/jsh share the Bourne language, not the /sbin/sh Korn parser.
isIrixKshDialect IrixSh = True
isIrixKshDialect IrixKsh = True
isIrixKshDialect _ = False

supportsDollarCommandSubstitution IrixBsh = False
supportsDollarCommandSubstitution IrixSh = False
supportsDollarCommandSubstitution _ = True

isKshShell Ksh = True
isKshShell IrixKsh = True
isKshShell IrixDtksh = True
isKshShell _ = False

flagsForRead = "sreu:n:N:i:p:a:t:"

-- IRIX sh uses -p to read from the coprocess, without an option argument.
flagsForReadFor IrixBsh = ""
flagsForReadFor IrixSh = "sreu:n:N:i:pa:t:"
flagsForReadFor IrixKsh = "sreu:n:N:i:pa:t:"
-- CDE 5.3.5 dtksh (ksh93 M-12/28/93d): read [-Aprs] [-d delim]
-- [-t timeout] [-u filenum] [name...].
flagsForReadFor IrixDtksh = "Aprsd:t:u:"
flagsForReadFor _ = flagsForRead

flagsForMapfile = "d:n:O:s:u:C:c:t"

declaringCommands = ["local", "declare", "export", "readonly", "typeset", "let"]

privilegeElevationCommands = ["sudo", "doas", "run0"]

prop_toIrixVersionRelease3 =
    toIrixVersion "v0.11.0-irix.3" == "0.11.0-irix.3"
prop_toIrixVersionRelease4 =
    toIrixVersion "v0.11.0-irix.4" == "0.11.0-irix.4"
prop_toIrixVersionRelease6 =
    toIrixVersion "v0.11.0-irix.6" == "0.11.0-irix.6"
prop_toIrixVersionRelease7 =
    toIrixVersion "v0.11.0-irix.7" == "0.11.0-irix.7"
prop_toIrixVersionSnapshot =
    toIrixVersion "v0.11.0-irix.4-2-g1234567" ==
        "0.11.0-irix.4-2-g1234567"
prop_toIrixVersionPackage =
    toIrixVersion "0.11.0" == "0.11.0-irix"

return []
runDataTests = $forAllProperties $ quickCheckWithResult (stdArgs { maxSuccess = 1 })
