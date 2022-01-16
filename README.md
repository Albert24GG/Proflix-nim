<h1 align="center">
  <br>
    <img src="./proflix.png" alt="Proflix-nim" width="200">
  <br>
  Proflix-nim
  <br>
  <br>
</h1>

## What is this?

Proflix-nim is a cross-platform tool written in nim that scrapes a list of torrent sites for magnet links and uses webtorrent to stream the media directly to mpv.

## Dependencies

- [webtorrent-cli](https://github.com/webtorrent/webtorrent-cli)
- [mpv](https://github.com/mpv-player/mpv)
- [nim](https://nim-lang.org/) (I recommend installing it via [choosenim](https://github.com/dom96/choosenim))
- [nimble](https://github.com/nim-lang/nimble) (it should come bundled with nim)

## Installation

Clone the repository and install the `os_files` nim module :

```sh
$ git clone https://github.com/Albert24GG/Proflix.git
$ cd ./Proflix-nim
$ nimble install os_files
```

## Usage

Cd into the Proflix-nim directory and compile the project:

```sh
$ nim -d:release -d:ssl c proflix.nim 
```
After that, run the executable file:
```sh
# On Windows systems
$ .\proflix.exe
# On Unix systems
$ ./proflix
```

## License

Project licensed under [GNU GPL3 License](https://www.gnu.org/licenses/gpl-3.0.html).
