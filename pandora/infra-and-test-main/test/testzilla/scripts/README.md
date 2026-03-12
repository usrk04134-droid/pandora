# Scripts

## plc_path_finder.py

The purpose of this script is to generate documentation that can be used as a help when using the [plc](../plc/plc_json_rpc.py) module.

When you want to `read` or `write` values to and from the PLC, you must know which address to use for a particular value.\
Finding that address can be quite cumbersome in the TIA portal GUI.

This script can traverse an entire Data Block (DB) in the PLC and create address strings for every value in that DB.

It is possible to get the output as both JSON or Markdown files, but for the purpose of documenting addresses, Markdown\
is more suitable.

```text
Usage: plc_path_finder.py generate [OPTIONS]

  Generate documentation from PLC Data Block paths

Options:
  -u, --url TEXT                  [default: https://192.168.100.10/api/jsonrpc]
  -s, --start-address TEXT        Address must start with a "SoftwareUnit.DataBlock" in quotes.  [required]
  -f, --format [MD|JSON]          [required]
  -o, --out TEXT                  Output directory for the generated files.  [default: /home/joel/repos/infra-and-
                                  test]
  -l, --log-level [DEBUG|INFO|WARNING|ERROR|CRITICAL]
                                  Set the logging verbosity level.  [default: INFO]
  -h, --help                      Show this message and exit.

  Example: plc_path_finder.py generate -s '"AdaptioCommunication.DB_AdaptioCommunication"' -f MD -f JSON
```

It is also possible to specify multiple start addresses, which will result in one file per address and format.

```text
plc_path_finder.py generate -s '"AdaptioCommunication.DB_AdaptioCommunication"' -s '"GeneralManager.DB_GeneralManager"' -f MD
```
