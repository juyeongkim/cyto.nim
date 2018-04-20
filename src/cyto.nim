# cyto
# Copyright Ju Yeong Kim
# A new awesome nimble package

import strutils
import streams
import tables
import os
import endians
import arraymancer

type
  Header = object
    version: string
    textStart: int
    textEnd: int
    dataStart: int
    dataEnd: int
    analysisStart: int
    analysisEnd: int
  Cyto* = object
    header*: Header
    text*: OrderedTableRef[string, string]
    data*: Tensor[float32]

proc readVersion*(file: string): string =
  var con = newFileStream(file, fmRead)
  result = readStr(con, 6)
  con.close()

proc readHeader*(file: string): Header =
  var header: Header
  header.version = readVersion(file)

  var con = newFileStream(file, fmRead)
  con.setPosition(7)

  let emptySection = readStr(con, 4)
  if emptySection != "    ":
    raiseAssert("Not a valid FCS file")
  
  header.textStart = readStr(con, 8).strip().parseInt()
  header.textEnd = readStr(con, 8).strip().parseInt()
  header.dataStart = readStr(con, 8).strip().parseInt()
  header.dataEnd = readStr(con, 8).strip().parseInt()
  header.analysisStart = readStr(con, 8).strip().parseInt()
  header.analysisEnd = readStr(con, 8).strip().parseInt()

  con.close()

  header

proc readText*(file: string): OrderedTableRef[string, string] =
  var header: Header = readHeader(file)

  var con = newFileStream(file, fmRead)

  con.setPosition(header.textStart)
  var rawText = readStr(con, header.textEnd - header.textStart + 1)
  con.close()
  
  var txt = rawText.split(rawText.substr(0, 0))
  txt.delete(0)
  txt.delete(txt.len - 1)
  
  var hash = newOrderedTable[string, string]()
  for i in countup(0, txt.len - 1, 2):
    hash[txt[i]] = txt[i + 1]

  hash

proc readData*(file: string): Tensor[float32] =
  var header = readHeader(file)
  var text = readText(file)

  var con = newFileStream(file, fmRead)
  con.setPosition(header.dataStart)

  let
    tot:int = text["$TOT"].strip.parseInt()
    par:int = text["$PAR"].strip.parseInt()
    n:int = tot * par

  var data = newSeq[seq[float32]](tot)
  var rag = newSeq[float32]()
  var row:int

  for i in 0..<n:
    var output:float32
    var input:float32 = readFloat32(con)
    bigEndian32(addr(output), addr(input))

    rag.add(output)
    if rag.len == par:
      data[row] = rag
      rag = newSeq[float32]()
      row.inc()
  
  con.close()

  data.toTensor()


proc readFCS*(file: string): Cyto  =
  var cyto: Cyto
  cyto.header = readHeader(file)
  cyto.text = readText(file)
  cyto.data = readData(file)

  cyto