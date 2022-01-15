import std/[httpclient, tables, strutils, nre, os, algorithm]
#import nigui
#import exp as fileExplorer


type
  TorrentFinder = object
    cacheDir: string
    results: seq[array[7, string]]
    urlPrefix: string
    header: string
    sitesInfo: Table[string, Table[string, string]]


proc initialize(): TorrentFinder =

  var siteRes: seq[array[7, string]] = @[] 
  let
    cache = ".torrentCache"
    prefix = "https://"
    agent = "Mozilla/5.0 (Windows NT 6.2; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/32.0.1667.0 Safari/537.36"
    site1 = {
                  "query": "/usearch/$#/?sortby=seeders&sort=desc",
                  "name": "<a.*class=\"cellMainLink\">(?:\r\n|\r|\n)(.+)</a>",
                  "link": "<a href=\"(.+)\" class=\"cellMainLink\">",
                  "seeders": "<td class=\"green center\">(?:\\r\\n|\\r|\\n| )(.+)</td>",
                  "leechers": "<td class=\"red lasttd center\">(?:\\r\\n|\\r|\\n| )(.+)</td>",
                  "time": "<td class=\"center\" title=\"(.+<br/>.+)\">",
                  "size": "<td class=\"nobr center\">(?:\\r\\n|\\r|\\n| )(.+?) </td>",
                  "magnet": "<a class=\"kaGiantButton \".*href=\"(magnet:.+?)\"><i class=\"ka ka-magnet\"></i></a>"
              }.toTable
    site2 = {
                  "query": "/sort-search/$#/seeders/desc/1/",
                  "name": "<a href=\"/torrent/\\d+/(.+)/\">.*</a>",
                  "link": "<a href=\"(/torrent/.+)\">.*</a>",
                  "seeders": "<td class=\"coll-2 seeds\">(\\d+)</td>",
                  "leechers": "<td class=\"coll-3 leeches\">(\\d+)</td>",
                  "time": "<td class=\"coll-date\">(.+)</td>",
                  "size": "<td class=\"coll-4 size.*\">(.+)<span.*</td>",
                  "magnet": "(magnet:.+?)\".on"
              }.toTable
    sitesInfoData = {"kickasstorrents.to": site1, "1337x.to": site2}.toTable
  if not dirExists(cache):
    createDir(cache)
  return TorrentFinder(cacheDir: cache, results: siteRes, urlPrefix: prefix, header: agent, sitesInfo: sitesInfoData)


proc getElementList(finder: TorrentFinder, site: string, name: string, page: string): seq[string] =
  var res =  newSeq[string]()
  for match in findIter(page, re(finder.sitesInfo[site][name])):
    res &= match.captures[0]
  return res


proc clearResults(finder: var TorrentFinder) = 
  finder.results.setLen(0)


proc cleanup(finder: TorrentFinder) = 
  removeDir(finder.cacheDir)


proc clearScreen() = 
  discard execShellCmd("clear")


proc printOptions(finder: TorrentFinder, numb: int) =
  var optionNumb = 1
  let optionString = "($#) [$#] [$#] [S:$#] [L:$#] $#"
  for option in finder.results:
    if optionNumb > numb:
      break
    stdout.write(optionString % [$optionNumb, option[6], option[5], 
      option[3], option[4], option[2]], '\n')
    inc(optionNumb)


proc isNumb(s: string): bool = 
  if len(s) == 0:
    return false
  for c in s:
    if not isDigit(c):
      return false
  return true


proc chooseOption(finder: TorrentFinder, numb: int, client: HttpClient): string =
  let 
    optionSize = min(len(finder.results), numb)
    optionString = "Choose a torrent to watch [1-$#]: " % [$optionSize]
  var 
    choice: int = -1
    choiceStr: string
  # read input until a valid number of options is returned
  while choice > optionSize or choice < 1:
    stdout.write(optionString)
    choiceStr = readline(stdin)
    if isNumb(choiceStr):
      choice = parseInt(choiceStr)
  let 
    magnetPage: string = client.getContent(finder.results[choice-1][1])
    magnetLink = magnetPage.find( re(finder.sitesInfo[finder.results[choice-1][0]]["magnet"]) ).get.captures[0]
  return magnetLink


proc compare(x, y: array[7, string]): int =
  # sort in descending order 
  if x[3].parseInt() < y[3].parseInt(): 1
  else: -1


proc fetchInfo(finder: var TorrentFinder, name: string, client: HttpClient): bool =
  var name = name.replace(" ", "%20")
  for site, regex in finder.sitesInfo:
    var url = $finder.urlPrefix & $site & $(regex["query"] % [name])
    var page: string
    try:
      page = client.getContent(url)
    except:
      continue
    var names = getElementList(finder, site, "name", page)
    if len(names) == 0:
      continue
    var
      links = getElementList(finder, site, "link", page)
      seeders = getElementList(finder, site, "seeders", page)
      leechers = getElementList(finder, site, "leechers", page)
      dates = getElementList(finder, site, "time", page)
      sizes = getElementList(finder, site, "size", page)
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
    stdout.write("No magnet links found!")
    return false
  # sort the sequence in descending order by number of seeds
  finder.results.sort(compare)
  return true


proc main() =
  var 
    # construct our object
    finder: TorrentFinder = initialize()
    # create new http client
    client: HttpClient = newHttpClient(userAgent=finder.header)
    optionNumString: string = ""
    optionNum: int
  clearScreen()
  stdout.write("🧲 Media to search: ")
  let name: string = readLine(stdin)
  # read input until a number is returned
  while not isNumb(optionNumString):
    stdout.write("Max number of results: ")
    optionNumString = readLine(stdin).strip()
  optionNum = parseInt(optionNumString)
  var choice: string
  if not finder.fetchInfo(name, client):
    stdout.write("Want to continue? (Y/n): ")
    choice = readLine(stdin).toLowerAscii()
    if choice == "y" or choice.isEmptyOrWhitespace():
      finder.clearResults()
      clearScreen()
      main()
    else:
      return
  finder.printOptions(optionNum)
  # get the magnet link of the selected media
  let magnetLink: string = finder.chooseOption(optionNum, client)
  var shellCommand: string = "webtorrent \"$#\" -o $# --mpv" % [magnetLink, finder.cacheDir]
  #select subtitles
  # execute the command and play the media
  discard execShellCmd(shellCommand)
  finder.cleanup()
  return


main()

#fileExplorer.window.show()
#fileExplorer.window.hide()
#app.run()