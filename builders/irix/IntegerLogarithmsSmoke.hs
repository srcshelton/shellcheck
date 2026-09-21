-- Private native dependency qualification; uses no additional test libraries.
module Main (main) where

import Control.Exception (SomeException, evaluate, try)
import Control.Monad (forM_, unless)
import Data.List (nub)
import Math.NumberTheory.Logarithms
import Numeric.Natural (Natural)

referenceLog :: Integer -> Integer -> Int
referenceLog base value
    | value < base = 0
    | otherwise = 1 + referenceLog base (value `quot` base)

assertEqual :: String -> Int -> Int -> IO ()
assertEqual label expected actual =
    unless (expected == actual) $ error
        (label ++ ": expected " ++ show expected ++ ", got " ++ show actual)

assertThrows :: String -> Int -> IO ()
assertThrows label value = do
    result <- try (evaluate value) :: IO (Either SomeException Int)
    case result of
        Left _ -> return ()
        Right n -> error (label ++ ": expected an exception, got " ++ show n)

main :: IO ()
main = do
    let exponents = [0,1,2,7,8,15,16,30,31,32,33,63,64,65,127,128,255,256,511,512]
        inputs = nub $ filter (> 0) $ [1..128] ++
            [2 ^ e + delta | e <- exponents, delta <- [-1,0,1]] ++
            [10 ^ e + delta | e <- [1,2,9,10,19,20,39,40], delta <- [-1,0,1]]
        bases = [2,3,7,10,16,31,32,33,257]
    forM_ inputs $ \n -> do
        let natural = fromInteger n :: Natural
            label = "n=" ++ show n
        assertEqual (label ++ " integerLog2") (referenceLog 2 n) (integerLog2 n)
        assertEqual (label ++ " naturalLog2") (referenceLog 2 n) (naturalLog2 natural)
        assertEqual (label ++ " integerLog10") (referenceLog 10 n) (integerLog10 n)
        assertEqual (label ++ " naturalLog10") (referenceLog 10 n) (naturalLog10 natural)
        if n <= toInteger (maxBound :: Int)
            then assertEqual (label ++ " intLog2") (referenceLog 2 n) (intLog2 (fromInteger n))
            else return ()
        if n <= toInteger (maxBound :: Word)
            then assertEqual (label ++ " wordLog2") (referenceLog 2 n) (wordLog2 (fromInteger n))
            else return ()
        forM_ bases $ \base -> do
            let expected = referenceLog base n
            assertEqual (label ++ " integerLogBase " ++ show base) expected (integerLogBase base n)
            assertEqual (label ++ " naturalLogBase " ++ show base) expected
                (naturalLogBase (fromInteger base) natural)
    assertThrows "naturalLog2 zero" (naturalLog2 0)
    assertThrows "naturalLog10 zero" (naturalLog10 0)
    assertThrows "naturalLogBase invalid base" (naturalLogBase 1 2)
    assertThrows "integerLog2 negative" (integerLog2 (-1))
    assertThrows "integerLogBase invalid base" (integerLogBase 1 2)
    putStrLn ("PASS integer/natural logarithms: " ++ show (length inputs) ++
        " positive inputs, nine bases, machine-word boundaries and invalid domains")
