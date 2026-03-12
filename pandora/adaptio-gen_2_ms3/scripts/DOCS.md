# Adaptivity report

## Prerequisites

Scilab installed. Version >= 2026

- Download tar ball from scilab site.
- Extract to somewhere like /usr/bin/scilab
- Edit .bashrc to add scilab to path

*Note: The apt package for scilab is not recommended as it is usually several version behind.*

## Run script

The scilab script is wrapped in a bash script in order to set some parameters before calling scilab

To run adaptivty report (bash):

```scripts/adaptivity_report.sh --quit-on-close```

Add ```--help``` to see what other options are available
