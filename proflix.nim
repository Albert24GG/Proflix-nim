import std/[httpclient, strutils, nre, os, algorithm, json]
import os_files/dialog


type
  TorrentFinder = ref object of RootObj
    cacheDir: string
    results: seq[array[7, string]]
    urlPrefix: string
    header: string
    sitesInfo: JsonNode


proc getInfo(): JsonNode = 
  try:
    return parseFile("sitesInfo.json")
  except:
    raise newException(OSError, "Json parsing error or sitesInfo.json file missing!")


proc initialize(): TorrentFinder =
  # create a new TorrentFinder Object
  new result
  
  # get the regex from .json file
  var info: JsonNode = getInfo()
  
  let siteRes: seq[array[7, string]] = @[] 
  result.cacheDir = ".torrentCache"
  result.results = siteRes
  result.urlPrefix = "https://"
  result.header = 
    "Mozilla/5.0 (Windows NT 6.2; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/32.0.1667.0 Safari/537.36"
  result.sitesInfo = info

  # create cache directory if it doesn't already exist
  if not dirExists(result.cacheDir):
    createDir(result.cacheDir)


proc getElementList(finder: TorrentFinder, site: string, name: string, page: string): seq[string] =
  var res =  newSeq[string]()
  for match in findIter(page, re(finder.sitesInfo[site][name][0].getStr())):
    res &= match.captures[0]
  return res


proc clearResults(finder: var TorrentFinder) = 
  finder.results.setLen(0)


proc cleanup(finder: TorrentFinder) = 
  removeDir(finder.cacheDir)


proc clearScreen() = 
  when defined windows:
    discard execShellCmd("cls")
  else:
    discard execShellCmd("clear")
    

proc isNumb(s: string): bool = 
  if len(s) == 0:
    return false
  for c in s:
    if not isDigit(c):
      return false
  return true


proc isValidChoice(choice: string): bool =
  return choice == "y" or choice.isEmptyOrWhitespace()


proc printOptions(finder: TorrentFinder, numb: int) =
  var optionNumb: Natural = 1
  let optionString: string = "($#) [$#] [$#] [$#] [S:$#] [L:$#] $#"
  for option in finder.results:
    if optionNumb > numb:
      break
    stdout.write(optionString % [$optionNumb, option[0], option[6], option[5], 
      option[3], option[4], option[2]], '\n')
    inc(optionNumb)


proc chooseOption(finder: TorrentFinder, numb: int, client: HttpClient): string =
  let 
    optionSize: Natural = 
      min(len(finder.results), numb)
    optionString: string = 
      "Choose a torrent to watch [1-$#]: " % [$optionSize]
  var 
    choice: int = -1
    choiceStr: string
  # read input until a valid number of options is returned
  while not (choice in 1 .. optionSize):
    stdout.write(optionString)
    choiceStr = stdin.readLine().strip()
    if isNumb(choiceStr):
      choice = parseInt(choiceStr)
  let 
    magnetPage: string = client.getContent(finder.results[choice-1][1])
    magnetLink = magnetPage.find( re(finder.sitesInfo[finder.results[choice-1][0]]["magnet"][0].getStr()) ).get.captures[0]
  return magnetLink


proc compare(x, y: array[7, string]): int =
  # sort in descending order 
  if x[3].parseInt() < y[3].parseInt(): 1
  else: -1


proc fetchInfo(finder: var TorrentFinder, name: string, client: HttpClient): bool =
  var name: string = 
    name.replace(" ", "%20")
  for site, regex in finder.sitesInfo:
    for query in regex["query"] :
      var url: string = 
        $finder.urlPrefix & $site & $(query.getStr() % [name])
      var page: string
      try:
        page = client.getContent(url)
      except:
        continue
      var names: seq[string] = 
        getElementList(finder, site, "name", page)
      if len(names) == 0:
        continue
      var
        links: seq[string] = 
          getElementList(finder, site, "link", page)
        seeders: seq[string] = 
          getElementList(finder, site, "seeders", page)
        leechers: seq[string] = 
          getElementList(finder, site, "leechers", page)
        dates: seq[string] = 
          getElementList(finder, site, "time", page)
        sizes: seq[string] = 
          getElementList(finder, site, "size", page)
      for cnt in countup(0, len(names)-1):
        # remove unwanted text from strings
        if site == "kickasstorrents.to":
          dates[cnt] = dates[cnt].replace("<br/>", " ") & " ago"
          names[cnt] = multiReplace(names[cnt], [("<strong class=\"red\">", "")])
          names[cnt] = multiReplace(names[cnt], [("</strong>", "")])
        else:
          names[cnt] = multiReplace(names[cnt], [("-", " ")])
        # add info to results sequence
        finder.results &= [site, finder.urlPrefix & site & links[cnt], names[cnt], seeders[cnt].strip(),
          leechers[cnt].strip(), dates[cnt], sizes[cnt]] 
  if len(finder.results) == 0:
    stdout.write("No magnet links found!\n")
    return false
  # sort the sequence in descending order by number of seeds
  finder.results.sort(compare)
  return true


proc selectSubFile(): string = 
  # open a file explorer and select subtitles
  var fileChooser: DialogInfo
  fileChooser.kind = dkOpenFile
  fileChooser.title = "Select subtitles file"
  var selection: string = fileChooser.show()
  if not selection.isEmptyOrWhitespace():
    return selection
  else:
    stdout.write("Did not specify any file. Do you want to try again?(Y/n): ")
    let choice: string = stdin.readLine().toLowerAscii()
    if choice.isValidChoice():
      return selectSubFile()
    else:
      return ""


proc selectDir(): string = 
  # open a file explorer and select download directory
  var fileChooser: DialogInfo
  fileChooser.kind = dkSelectFolder
  fileChooser.title = "Select download directory"
  var selection: string = fileChooser.show()
  if not selection.isEmptyOrWhitespace():
    return selection
  else:
    stdout.write("Did not specify any download directory. Do you want to try again?(Y/n): ")
    let choice: string = stdin.readLine().toLowerAscii()
    if choice.isValidChoice():
      return selectDir()
    else:
      return ""


proc chooseApp(): int =
    # Choose whether to download or stream the media
    stdout.write("What do you want to do?\n  1) Download media\n  2) Stream media\n")
    let optionString: string = "Choose an option [1-2]: "
    var 
      choice: int  = -1
      choiceString: string
    while not (choice in 1 .. 2):
      stdout.write(optionString)
      choiceString = stdin.readLine().strip()
      if isNumb(choiceString):
        choice = parseInt(choiceString)
    return choice


proc main() =
  var 
    # construct our object
    finder: TorrentFinder = initialize()
    # create new http client
    client: HttpClient = newHttpClient(userAgent=finder.header)
    optionNumString: string = ""
    optionNum: int
    shellCommand: string
    downloadDir: string
  clearScreen()
  let appOption: int = chooseApp()
  if appOption == 1:
    stdout.write("Select download directory:\n")
    shellCommand = "webtorrent download \"$#\""
    downloadDir = selectDir()
    if not downloadDir.isEmptyOrWhitespace():
      shellCommand &= " -o $# "
  else:
    shellCommand = "webtorrent \"$#\" -o $# --mpv"
  stdout.write("🧲 Media to search: ")
  let name: string = stdin.readLine()
  # read input until a number is returned
  while not isNumb(optionNumString) or parseInt(optionNumString) < 1:
    stdout.write("Max number of results: ")
    optionNumString = stdin.readLine().strip()
  optionNum = parseInt(optionNumString)
  var choice: string
  if not finder.fetchInfo(name, client):
    stdout.write("Want to continue? (Y/n): ")
    choice = stdin.readLine().toLowerAscii()
    if isValidChoice(choice):
      finder.clearResults()
      clearScreen()
      main()
    else:
      return
  finder.printOptions(optionNum)
  # get the magnet link of the selected media
  let magnetLink: string = finder.chooseOption(optionNum, client)
  if appOption == 1:
    shellCommand = shellCommand % [magnetLink, downloadDir]
  else:
    shellCommand = shellCommand % [magnetLink, finder.cacheDir]
    #select subtitles
    stdout.write("Do you want to load any subtitles file?(Y/n): ")
    choice = stdin.readLine().toLowerAscii()
    var subPath: string
    if isValidChoice(choice):
      subPath = selectSubFile()
      if not subPath.isEmptyOrWhitespace():
        shellCommand = shellCommand & " -t $#" % subPath 
    # execute the command and play the media
  discard execShellCmd(shellCommand)
  finder.cleanup()


if isMainModule:
  main()