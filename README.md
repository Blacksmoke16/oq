# oq

[![Built with Crystal](https://img.shields.io/badge/built%20with-crystal-000000.svg?style=flat-square)](https://crystal-lang.org/)
[![Build Status](https://travis-ci.org/Blacksmoke16/oq.svg?branch=master)](https://travis-ci.org/Blacksmoke16/oq)
[![Latest release](https://img.shields.io/github/release/Blacksmoke16/oq.svg?style=flat-square)](https://github.com/Blacksmoke16/oq/releases)
[![oq](https://snapcraft.io/oq/badge.svg)](https://snapcraft.io/oq)

A performant, portable `jq` wrapper thats facilitates the consumption and output of formats other than JSON; using `jq` filters to transform the data.

* Portable single binary for Linux/MacOS, statically linked for usage on Linux machines.
* Performant, similar performance with JSON data compared to `jq`.  Slightly longer execution time when going to/from a non JSON format.

## Installation

### Linux distrobutions supporting `snap` packages:

```bash
snap install oq
```

### MacOS: (Soon)

```bash
brew install oq
```

## Usage

Use the `oq` binary, with a few custom arguments.  All other arguments get passed to `jq`.

```bash
Usage: oq [--help] [oq-arguments] [jq-arguments] jq_filter [file [files...]]
    --help                          Show this help message.
    -i FORMAT, --input FORMAT       Format of the input data. Supported formats: json, yaml, xml.
    -o FORMAT, --output FORMAT      Format of the output data. Supported formats: json, yaml, xml.
    --xml-root ROOT                 Name of the root XML element if converting to XML.
```

## Roadmap

### Input Formats:

- [x] JSON
- [ ] XML
- [x] YAML

### Output Formats:

- [x] JSON
- [x] XML
- [x] YAML

## Contributing

1. Fork it (<https://github.com/Blacksmoke16/oq/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Blacksmoke16](https://github.com/Blacksmoke16) Blacksmoke16 - creator, maintainer
