# oq

[![Built with Crystal](https://img.shields.io/badge/built%20with-crystal-000000.svg?logo=crystal)](https://crystal-lang.org/)
[![CI](https://github.com/blacksmoke16/oq/workflows/CI/badge.svg)](https://github.com/blacksmoke16/oq/actions?query=workflow%3ACI)
[![Latest release](https://img.shields.io/github/release/blacksmoke16/oq.svg?color=teal&logo=github)](https://github.com/blacksmoke16/oq/releases)
[![oq](https://snapcraft.io/oq/badge.svg)](https://snapcraft.io/oq)
[![oq](https://img.shields.io/aur/version/oq?label=oq&logo=arch-linux)](https://aur.archlinux.org/packages/oq/)
[![oq-bin](https://img.shields.io/aur/version/oq-bin?label=oq-bin&logo=arch-linux)](https://aur.archlinux.org/packages/oq-bin/)

A performant, portable [jq](https://github.com/stedolan/jq/) wrapper thats facilitates the consumption and output of formats other than JSON; using `jq` filters to transform the data.

* Compiles to a single binary for easy portability.
* Performant, similar performance with JSON data compared to `jq`.  Slightly longer execution time when going to/from a non-JSON format.  
* Supports various other input/output [formats](https://blacksmoke16.github.io/oq/OQ/Format.html), such as `XML` and `YAML`.
* Can be used as a dependency within other Crystal projects.

## Installation

### Linux

A statically linked binary for Linux `x86_64` as available on the [Releases](https://github.com/Blacksmoke16/oq/releases) tab.  Additionally it can also be installed via various package managers.

#### Snapcraft

For more on installing & using `snap` with your Linux distribution, see the [official documentation](https://docs.snapcraft.io/installing-snapd).

```sh
sudo snap install oq
```

#### Arch Linux

Using [yay](https://github.com/Jguer/yay):

```sh
yay -S oq
```

A pre-compiled version is also available:

```sh
yay -S oq-bin
```

### macOS

```sh
brew install oq
```

### From Source

If building from source, `jq` will need to be installed separately. Installation instructions can be found in the [official documentation](https://stedolan.github.io/jq/).

Requires Crystal to be installed, see the [installation documentation](https://crystal-lang.org/install).

```sh
git clone https://github.com/Blacksmoke16/oq.git
cd oq/
shards build --production --release
```

The built binary will be available as `./bin/oq`.  This can be relocated elsewhere on your machine; be sure it is in your `PATH` to access it as `oq`.

### Docker

`oq` can easily be included into a Docker image by fetching the static binary from Github for the version of `oq` that you want.

```dockerfile
# Set an arg to store the oq version that should be installed.
ARG OQ_VERSION=1.3.2

# Grab the binary from the latest Github release and make it executable; placing it within /usr/local/bin.  Can also put it elsewhere if you so desire.
RUN wget https://github.com/Blacksmoke16/oq/releases/download/v${OQ_VERSION}/oq-v${OQ_VERSION}-linux-x86_64 -O /usr/local/bin/oq && chmod +x /usr/local/bin/oq

# Or using curl (needs to follow Github's redirect):
RUN curl -L -o /usr/local/bin/oq https://github.com/Blacksmoke16/oq/releases/download/v${OQ_VERSION}/oq-v${OQ_VERSION}-linux-x86_64 && chmod +x /usr/local/bin/oq

# Also be sure to install jq if it is not already!
```

### Existing Crystal Project

Add the following to your `shard.yml` and run `shards install`.

```yaml
dependencies:
  oq:
    github: blacksmoke16/oq
    version: ~> 1.3.0
```

## Usage

### CLI

Use the `oq` binary, with a few optional custom arguments, see `oq --help`.  All other arguments get passed to `jq`. See [jq manual](https://stedolan.github.io/jq/manual/) for details.

### Library

Checkout the [API Documentation](https://blacksmoke16.github.io/oq/OQ/Processor.html) for using `oq` within an existing Crystal project.

### Examples

Consume JSON and output XML

```sh
$ echo '{"name": "Jim"}' | oq -o xml .
<?xml version="1.0" encoding="UTF-8"?>
<root>
  <name>Jim</name>
</root>
```

Consume YAML from a file and output XML

data.yaml

```yaml
---
name: Jim
numbers:
  - 1
  - 2
  - 3
```

```sh
$ oq -i yaml -o xml . data.yaml 
<?xml version="1.0" encoding="UTF-8"?>
<root>
  <name>Jim</name>
  <numbers>1</numbers>
  <numbers>2</numbers>
  <numbers>3</numbers>
</root>
```

Use `oq` as a library, consuming some raw `JSON` input, convert it to `YAML`, and write the transformed data to a file.

```crystal
require "oq"

# This could be any `IO`, e.g. an `HTTP` request body, etc.
input_io = IO::Memory.new %({"name":"Jim"})

# Create a processor, specifying that we want the output format to be `YAML`.
processor = OQ::Processor.new output_format: :yaml

File.open("./out.yml", "w") do |file|
  # Process the data using our custom input and output IOs.
  # The first argument represents the input arguments;
  # i.e. the filter and/or any other arguments that should be passed to `jq`.
  processor.process ["."], input: input_io, output: file
end
```

## Contributing

1. Fork it (<https://github.com/Blacksmoke16/oq/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [George Dietrich](https://github.com/Blacksmoke16) - creator, maintainer
- [Michael Springer](https://github.com/sprngr) - contributor
