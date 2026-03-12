# Pipeline shell scripts

## Description

This directory contains scripts that are intended to be used in a Gitlab pipeline job environment.\
They are not intended to be run locally, even if most of them can be with the right setup (makes it easier to test them during development).

For logging and GitLab sections in job logs, the scripts rely on functions contained in the `logger.sh` module. This means that they need to be able to source that file to get access to those functions.\
The use of `sections`, targets specific GitLab functionality and wont do much when run outside of that environment.

## The logger module

The `logger.sh` module is not a shell script in itself, and is only intended to be sourced from other scripts.\
The logger module contains helper functions for logging messages and functions for creating sections in a GitLab pipeline job log.

## The scripts

### create-and-merge-request.sh

The purpose of this script is to merge modified files by creating a merge request and if possible, merge it.

### deploy-adaptio-os.sh

The purpose of this script is to deploy Adaptio OS to a target system. It does this by performing a nixos-rebuild with boot,\
after which the system is rebooted. The script will wait for the system to boot after which it will check the status of the Adaptio service.

### download-from-repository.sh

The purpose of this script is to download a file from a repository. It uses the GitLab API to do this.

### get-branch-name.sh

The purpose of this script is to return the branch name for a given commit SHA.\
This script is mainly used in tag pipelines where there is no predefined GitLab variable that contains the branch name.

### get-project-id.sh

The purpose of this script is to return the GitLab project id for a given project name.\
The script is intended for `esab/abw` projets and assumes that the given project name is located under that path.
