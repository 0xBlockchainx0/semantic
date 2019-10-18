{-# LANGUAGE TypeApplications #-}
module Main (main) where

import System.Environment
import TreeSitter.Unmarshal
import TreeSitter.Python.AST
import TreeSitter.Python
import Source.Range
import Source.Span
import Data.ByteString.Char8
import Data.ByteString (pack, readFile, ByteString)
import System.IO (FilePath)
import Options.Applicative hiding (style)
import Data.Semigroup ((<>))
import Text.Pretty.Simple (pPrint)

data SemanticAST = SemanticAST
  { format :: Format
  , source :: Either FilePath Prelude.String
  }

parseAST :: Parser SemanticAST
parseAST = SemanticAST
  <$> option auto
    ( long "format"
    <> help "Specify desired output: show, json, sexpression" )
  <*> (Left <$> strOption
      ( long "sourceFile"
      <> metavar "FILEPATH"
      <> help "Specify filepath containing source code to parse" )
    <|> Right <$> strOption
      ( long "sourceString"
      <> metavar "STRING"
      <> help "Specify source input to parse"
      ))

main :: IO ()
main = generateAST =<< execParser opts

generateAST :: SemanticAST -> IO ()
generateAST (SemanticAST format source) = do
  bytestring <- case source of
    Left filePath -> do
      Data.ByteString.readFile filePath
    Right source -> do
      pure $ Data.ByteString.Char8.pack source
  ast <- parseByteString @TreeSitter.Python.AST.Module @(Range, Span) tree_sitter_python bytestring
  case format of
    Show -> print ast
    Pretty -> pPrint ast

opts :: ParserInfo SemanticAST
opts = info (parseAST <**> helper)
  ( fullDesc
 <> progDesc "Parse source code and produce an AST"
 <> header "semantic-ast is a package used to parse source code" )

-- TODO: Define formats for json, sexpression, etc.
data Format = Show | Pretty
  deriving (Read)