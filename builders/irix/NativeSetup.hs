-- A reusable Setup runner using the Cabal library bundled with native GHC.
-- Avoid building an HTTP client / package solver on the target: dependency
-- sources, versions and flags are resolved and verified before transfer.
import Distribution.Simple (autoconfUserHooks, defaultMain, defaultMainWithHooks)
import System.Environment (getArgs, withArgs)

main :: IO ()
main = do
    args <- getArgs
    case args of
        "Simple" : rest -> withArgs rest defaultMain
        "Configure" : rest -> withArgs rest (defaultMainWithHooks autoconfUserHooks)
        _ -> ioError (userError "usage: native-setup Simple|Configure CABAL_ARGUMENTS")
