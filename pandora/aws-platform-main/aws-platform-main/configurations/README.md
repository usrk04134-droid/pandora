# Configuration

These configurations are intended to work in a layered manner. When building one can set -v CONFIGURATION="[base, my_fancy_configuration, ...]" to set which configurations are choosen. The configurations are applied in the order they are written, so a later configuration may overwrite file(s) from an earlier one.

## Base configuration

The base configuration includes I/O-addresses where that makes sense (Adaptio, PABs, etc.). The base configuration files are meant to be as granular as possible so it is easy to override the addresses for single components.

## Components

If the configuration contains optional components this should be stated in a \_components\_ file in the configuration directory. The format of this file is a comma separated list:

```text
FLUX_BIG_BAG,LASER_POINTER
```

### Valid components

Right now there are no selectable components, in the future there will be a list with descriptions here.
