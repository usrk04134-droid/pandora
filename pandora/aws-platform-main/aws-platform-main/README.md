# AWS PLC Platform

## Building

### Prerequisites

The user is logged in to the registries used:

```bash
apax login
```

### Building

To build the apax project use the build command:

```bash
apax install # To install the dependencies
apax build
```

### Using the docker image to build

The Docker image is built using Nix flakes with Ubuntu 24.04 as the base image. To build and load the image:

```bash
# Build the image
nix build .#containerImage

# Load into Docker
docker load < result
```

NOTE: If the container requires special parameters for running apax commands (due to bubblewrap), use:

```bash
--cap-add SYS_ADMIN --security-opt apparmor=unconfined --security-opt seccomp=unconfined
```

Test if these flags are needed with: `docker run --rm aws-platform-env:0.7.0 apax --version`

### Updating the docker image

The image is versioned separately from the PLC product, and the version tag in the flake.nix must be bumped manually whenever a change is made that
affects the image.

```nix
packages.containerImage = pkgs.dockerTools.buildLayeredImage {
  name = "aws-platform-env";
  tag = "0.8.0";
```

## Loading software to PLC

```bash
apax reset-plc # Builds the software with base configuration and then downloads everything and resets the PLC.
apax update-plc # Builds the software with base configuration and then does a delta download and resets the PLC.

apax load-plc # Downloads a previously built software (delta download) without restarting/resetting the PLC.
apax load-plc-reinit # Same as load-plc but will also reset the PLC.
apax load-plc-reset # Same as reset-plc but will download a previously built software.
```

### Troubleshooting

1. Make sure that the clock on the PC and PLC is set correctly.

## Basic architecture

The basic architecture intends to allow for using the same main software in multiple configurations.

![hw-config](./assets/hardware-configuration.svg)

### TIA Project

The TIA project is where all hardware connected to the PLC is set-up (I/O, servo drives, etc.). This is where we map the hardware to I/O address space.
This project is meant to be generic for many different setups. To use a TIA project for the hardware configuration is an interim solution and will be replaced by hardware configuration in AX once support for all needed functionality is implemented.

### Machine configuration

This is the configuration file(s) that decides what modules to use, and maps the Module I/O-structs to the correct I/O-addresses.

### Main configuration

This file contains the module configurations, will be evaluated at compile time to avoid larger misconfigurations.

### PLC program

This is where the real magic happens.

## Configurations

A configuration is made by adding a new directory in the configurations directory. The name of the configuration is the same as the folder. It can contain one file named \_components\_ that lists the modules that are used in the configuration, for example:

```text
FLOOD_LIGHTS,FLUX_BIG_BAG
```

The list should be a single line with no white-space, items separated by comma (,).

Furthermore the configuration directory can contain any number of .st files that specifies the I/O setup of the different modules. A short example:

```iecst
USING Siemens.Simatic.S71500.Tasks;

NAMESPACE My.Name.Space
      CONFIGURATION FloodLightsConfiguration
            TASK FloodLightsIoTask;

            PROGRAM FloodLightsIoProgram WITH FloodLightsIoTask : FloodLightsIo;

            // Structs containing I/O objects (DigitalInput etc.)
            // These are defined together with the model.
            // These will be mapped to the appropriate objects in MainConfiguration.st, _if_ the corresponding module is enabled in _modules.
            VAR_GLOBAL
                  I_FloodLight1 : FloodLightInputs;
                  I_FloodLight2 : FloodLightInputs;
                  Q_FloodLight1 : FloodLightOutputs;
                  Q_FloodLight2 : FloodLightOutputs;
            END_VAR

            // Mapping to the I/O for this specific machine type/model
            VAR_GLOBAL
                  DI_FloodLight1_Enabled AT %IX10.0: BOOL;
                  DI_FloodLight2_Enabled AT %IX10.1: BOOL;
                  DQ_FloodLight1_Enable AT %QX10.0: BOOL;
                  DQ_FloodLight2_Enable AT %QX10.1: BOOL;
            END_VAR
      END_CONFIGURATION

      PROGRAM FloodLightsIo
            // Write outputs
            Q_FloodLight1.Enable.Write(DQ_FloodLight1_Enable);
            Q_FloodLight2.Enable.Write(DQ_FloodLight2_Enable);

            // Read inputs
            I_FloodLight1.Enabled.Read(DI_FloodLight1_Enabled);
            I_FloodLight2.Enabled.Read(DI_FloodLight2_Enabled);
      END_PROGRAM
END_NAMESPACE
```

There is a configuration named "base" that is always added, this contains the minimum set of things for a "standard" system.
The configuration files are addative, and will be added in the order written. With later configuration files overwriting the previous ones.

### Selecting configurations

The configurations can be selected at build time as such:

```bash
apax build-with-config flood_lights,flux_big_bag
```

## Cheatsheet

There is a selection of utility scripts available in the apax.yml file, here is a list of the most useful ones:

```bash
apax build-with-config <config> # Builds with a specific configuration, see "Configurations" above.

apax test # Runs all unit tests

apax update-plc # Tries to update the SW in the PLC while running.

apax reset-plc # Will stop the PLC, then download the complete program, and start it again. This will reset everything.
```

# The web hmi

The web application is available at <https://$IP_ADDRESS/~awsplatform/index.html>.
It is a small service HMI mainly used for testing and setting things that "should never change".

```bash
apax reset-web-app # Will delete and re-upload the web application/hmi

apax create-web-app # Will create and upload the web application/hmi
```

# Styleguide

See <https://console.simatic-ax.siemens.io/docs/st/st-styleguide>

# Pipeline

The templates used in the PLC pipelines can be found in the [infra-and-test][infra-and-test-.gitlab-ci] project. Read more about these in [README.md][infra-and-test-.gitlab-ci-README].

## Building test-env

The [build-and-push-flake.yml][build-and-push-flake] template from infra-and-test is used in [.gitlab-ci.yml] to create the aws-platform test environment. The following inputs are provided to the template.

* job-matrix: Image name is `aws-platform-env`
* job-rules: When a flake file changes in MR or protected branch

Once the test-environment is built, the image is pushed to the container registry at [aws-platform-env]

## Building PLC software

The [plc-apax-build.yml][plc-apax-build] template from infra-and-test is used in [.gitlab-ci.yml] to build the PLC software. The following inputs are provided to the template

* image-version: latest version of `aws-platform-env`
* job-rules: If files under `src` or `configuration` folders in the [aws-platform][aws-platform-repo] repo change
* login-token: $PLC_APAX_TOKEN. The secret is stored in Azure KeyVault, and the GitLab group variable is created through Terraform.\

> [!important]
When the secret is updated in the Azure KeyVault, Terraform must be run again to update the value of the `PLC_APAX_TOKEN` variable.

## Testing PLC software

The [plc-apax-test.yml][plc-apax-test] template from infra-and-test is used in [.gitlab-ci.yml] to test the PLC software. The following inputs are provided to the template.

* image-version: mostly latest version of `aws-platform-env`
* job-rules: If files under `src` or `test` folders in the [aws-platform][aws-platform-repo] repo change.
* login-token: $PLC_APAX_TOKEN

## Deploying PLC software

This feature is not implemented yet. It is possible to do using `Apax`. More details will be provided after the completion of [ADT-1177](https://esabgrnd.jira.com/jira/software/c/projects/ADT/boards/590/backlog?selectedIssue=ADT-1177)

[.gitlab-ci.yml]: .gitlab-ci.yml
[infra-and-test-.gitlab-ci]: https://gitlab.com/esab/abw/infra-and-test/-/tree/main/.gitlab-ci
[infra-and-test-.gitlab-ci-README]: https://gitlab.com/esab/abw/infra-and-test/-/blob/main/.gitlab-ci/README.md
[build-and-push-flake]: https://gitlab.com/esab/abw/infra-and-test/-/blob/main/.gitlab-ci/build-and-push-flake.yml?ref_type=heads
[aws-platform-repo]: https://gitlab.com/esab/abw/plc/aws-platform
[aws-platform-env]: https://gitlab.com/esab/abw/plc/aws-platform/container_registry/8500769
[plc-apax-build]: https://gitlab.com/esab/abw/infra-and-test/-/blob/main/.gitlab-ci/plc-apax-build.yml?ref_type=heads
[plc-apax-test]: https://gitlab.com/esab/abw/infra-and-test/-/blob/main/.gitlab-ci/plc-apax-test.yml?ref_type=heads

# Updating token in Azure

Login to Azure (this method will soon stop working, for alternatives see <https://go.microsoft.com/fwlink/?linkid=2276314>):

`az login --allow-no-subscriptions --username <username> --password=<password>`

Set the token:

`az keyvault secret set --name plc-apax-ci-token --vault-name kv-adaptio-dev-fgt --value <token>`
