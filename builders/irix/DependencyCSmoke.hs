{-# LANGUAGE ForeignFunctionInterface #-}
module Main where

import Control.Monad (unless)
import Data.Bits (xor)
import Data.Word
import Foreign
import Foreign.C.Types

foreign import ccall unsafe "hsprimitive_memset_Word64"
    fill64 :: Ptr Word64 -> CPtrdiff -> CSize -> Word64 -> IO ()
foreign import ccall unsafe "hsprimitive_memset_Double"
    fillDouble :: Ptr Double -> CPtrdiff -> CSize -> Double -> IO ()
foreign import ccall unsafe "hsprimitive_memset_Float"
    fillFloat :: Ptr Float -> CPtrdiff -> CSize -> Float -> IO ()
foreign import ccall unsafe "_hs_text_memcpy"
    textCopy :: Ptr Word16 -> CSize -> Ptr Word16 -> CSize -> CSize -> IO ()
foreign import ccall unsafe "_hs_text_memcmp"
    textCompare :: Ptr Word16 -> CSize -> Ptr Word16 -> CSize -> CSize -> IO CInt
foreign import ccall unsafe "_hs_text_decode_latin1"
    latin1 :: Ptr Word16 -> Ptr Word8 -> Ptr Word8 -> IO ()
foreign import ccall unsafe "_js_decode_string"
    decodeJSON :: Ptr Word16 -> Ptr CSize -> Ptr Word8 -> Ptr Word8 -> IO CInt
foreign import ccall unsafe "hashable_fnv_hash_offset"
    hashOffset :: Ptr Word8 -> CLong -> CLong -> CLong -> IO CLong

check :: String -> Bool -> IO ()
check label ok = do
    unless ok (error ("FAIL " ++ label))
    putStrLn ("PASS " ++ label)

jsonCase :: String -> [Word16] -> IO ()
jsonCase input expected = withArray (map (fromIntegral . fromEnum) input) $ \src ->
    withArray (replicate 20 0x5a5a) $ \dest -> alloca $ \off -> do
        poke off 1
        result <- decodeJSON dest off src (src `plusPtr` length input)
        n <- peek off
        actual <- peekArray 20 dest
        check "aeson JSON decoding and UTF-16 guards"
            (result == 0 && n == fromIntegral (1 + length expected) &&
             actual == [0x5a5a] ++ expected ++ replicate (19 - length expected) 0x5a5a)

main :: IO ()
main = do
    withArray ([7,7,7,7,7] :: [Word64]) $ \p -> do
        fill64 p 1 3 0x12345678abcdef01
        values <- peekArray 5 p
        check "primitive Word64 N32 arguments and guards"
            (values == [7,0x12345678abcdef01,0x12345678abcdef01,0x12345678abcdef01,7])
    withArray ([7,7,7,7] :: [Double]) $ \p -> do
        fillDouble p 1 2 (-13.25)
        values <- peekArray 4 p
        check "primitive Double N32 arguments and guards" (values == [7,-13.25,-13.25,7])
    withArray ([7,7,7,7] :: [Float]) $ \p -> do
        fillFloat p 1 2 1.75
        values <- peekArray 4 p
        check "primitive Float N32 arguments and guards" (values == [7,1.75,1.75,7])
    withArray ([1,0x1234,0xabcd,4] :: [Word16]) $ \src ->
        withArray ([9,9,9,9,9] :: [Word16]) $ \dest -> do
            textCopy dest 1 src 1 2
            result <- textCompare dest 1 src 1 2
            values <- peekArray 5 dest
            check "text offset memory copy/compare guards" (result == 0 && values == [9,0x1234,0xabcd,9,9])
    withArray ([0,65,128,255] :: [Word8]) $ \src ->
        withArray ([0x5a5a,0,0,0,0,0x5a5a] :: [Word16]) $ \dest -> do
            latin1 (dest `plusPtr` 2) src (src `plusPtr` 4)
            values <- peekArray 6 dest
            check "text Latin-1 decoding and guards" (values == [0x5a5a,0,65,128,255,0x5a5a])
    jsonCase "a\\n\\u20ac\\uD83D\\uDE00" [97,10,0x20ac,0xd83d,0xde00]
    jsonCase "plain" [112,108,97,105,110]
    withArray ([92,117,68,67,48,48] :: [Word8]) $ \src ->
        allocaArray 8 $ \dest -> alloca $ \off -> do
            poke off 0
            result <- decodeJSON dest off src (src `plusPtr` 6)
            check "aeson rejects lone low surrogate" (result /= 0)
    let bytes = [0,65,255,128,33] :: [Word8]
        expected = foldl (\h b -> (h * 16777619) `xor` fromIntegral b) 2166136261 bytes :: Word32
    withArray (99:bytes) $ \src -> do
        result <- hashOffset src 1 5 (fromIntegral (2166136261 :: Word32))
        check "hashable N32 unsigned wrapping and offset" ((fromIntegral result :: Word32) == expected)
    putStrLn "IRIX dependency C/FFI smoke tests passed"
