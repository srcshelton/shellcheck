-- Native text/FFI qualification without extra test-library dependencies.
module Main (main) where

import Control.Monad (forM_, unless)
import Data.Char (chr)
import qualified Data.ByteString as B
import qualified Data.ByteString.Lazy as BL
import qualified Data.Text as T
import qualified Data.Text.Encoding as E
import qualified Data.Text.Lazy as TL
import qualified Data.Text.Lazy.Encoding as EL
import Data.Word (Word8)

assertEqual :: (Eq a, Show a) => String -> a -> a -> IO ()
assertEqual label expected actual =
    unless (expected == actual) $ error
        (label ++ ": expected " ++ show expected ++ ", got " ++ show actual)

vectors :: [(Int, [Word8])]
vectors =
    [(0, [0]), (0x41, [0x41]), (0x7f, [0x7f]),
     (0x80, [0xc2, 0x80]), (0x7ff, [0xdf, 0xbf]),
     (0x800, [0xe0, 0xa0, 0x80]), (0xd7ff, [0xed, 0x9f, 0xbf]),
     (0xe000, [0xee, 0x80, 0x80]), (0xffff, [0xef, 0xbf, 0xbf]),
     (0x10000, [0xf0, 0x90, 0x80, 0x80]),
     (0x10ffff, [0xf4, 0x8f, 0xbf, 0xbf])]

checkEncoding :: String -> String -> B.ByteString -> IO ()
checkEncoding label string bytes = do
    let text = T.pack string
    assertEqual (label ++ " encode") bytes (E.encodeUtf8 text)
    assertEqual (label ++ " decode") text (E.decodeUtf8 bytes)
    -- ByteString slices exercise nonzero byte offsets on big-endian N32.
    forM_ [0..7] $ \offset -> do
        let sliced = B.drop offset (B.append (B.replicate offset 0x61) bytes)
        assertEqual (label ++ " offset " ++ show offset) text (E.decodeUtf8 sliced)
    -- Split each multibyte sequence at every possible chunk boundary.
    forM_ [0..B.length bytes] $ \offset -> do
        let chunks = BL.fromChunks [B.take offset bytes, B.drop offset bytes]
        assertEqual (label ++ " chunk " ++ show offset)
            string (TL.unpack (EL.decodeUtf8 chunks))

main :: IO ()
main = do
    checkEncoding "empty" "" B.empty
    forM_ vectors $ \(codepoint, bytes) ->
        checkEncoding (show codepoint) [chr codepoint] (B.pack bytes)
    checkEncoding "mixed" (map (chr . fst) vectors) (B.pack (concatMap snd vectors))
    let latin1 = B.pack [0..255]
    assertEqual "latin1" (map chr [0..255]) (T.unpack (E.decodeLatin1 latin1))
    let large = T.replicate 4096 (T.pack (map (chr . fst) vectors))
    assertEqual "large buffer" large (E.decodeUtf8 (E.encodeUtf8 large))
    forM_ [[0x80], [0xc0,0x80], [0xc2], [0xe0,0x80,0x80],
           [0xed,0xa0,0x80], [0xf4,0x90,0x80,0x80], [0xff]] $ \bytes ->
        case E.decodeUtf8' (B.pack bytes) of
            Left _ -> return ()
            Right value -> error ("invalid UTF-8 accepted: " ++ show (bytes, value))
    putStrLn "PASS text UTF-8 boundaries, byte offsets, lazy chunks, Latin-1, large buffer and invalid sequences"
