{-# LANGUAGE ForeignFunctionInterface #-}
module Main where
import Data.Word
import Foreign.C.Types
import System.Exit

foreign import ccall unsafe "armv6_abi"
    armv6Abi :: CDouble -> CFloat -> Word64 -> IO CDouble

main :: IO ()
main = do
    value <- armv6Abi 1.25 2.5 4294967297
    if value == 4294967300.75
        then putStrLn "PASS ARMv6 Haskell/C hard-float/64-bit ABI"
        else exitFailure
