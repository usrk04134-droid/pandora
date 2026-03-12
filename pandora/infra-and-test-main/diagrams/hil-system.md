# HIL Architecture

- [HIL Architecture](#hil-architecture)
   - [Introduction](#introduction)
- [Setup](#setup)
   - [OS](#os)
   - [PLC SW](#plc-sw)
- [Deployment](#deployment)
   - [Runner](#runner)
- [Connectivity](#connectivity)
   - [Interfaces to HIL System](#interfaces-to-hil-system)
   - [Protocols to HIL System](#protocols-to-hil-system)
   - [Interfaces to System Under Test (HIL Rig)](#interfaces-to-system-under-test-hil-rig)
- [HIL tech stack Diagrams](#hil-tech-stack-diagrams)
   - [C4 Context](#c4-context)
   - [C4 Container](#c4-container)
   - [C4 Component - HIL PC](#c4-component---hil-pc)
   - [C4 Component - HIL SUT](#c4-component---hil-sut)
- [References](#references)

## Introduction

This document attempts to answer the following questions related to the HIL setup:

1. What is the architecture of the HIL system?
1. What are the structural elements of the system?
1. How are they related to each other?
1. What are the underlying principles and rationale that guide the answers to the previous questions?

All the ADRs in this repository shall be taken into account when reading this document as it is based on the reader being up-to-date with their content.

# Setup

## OS

We want Linux but also need a Windows machine (VM) to run the Siemens TIA Portal PLC software. For this NixOS is the option we will go for. It is the OS of choice in order to continue with the declarative setup used in CI as well as the fact that it is the os used for Adaptio SW.

## PLC SW

Siemens TIA Portal will be running in a Windows VM using a QEMU setup.

# Deployment

Options:

- NixOps (aka NixOps2). Not in active development and not viable
- NixOps4 (superseds NixOps). Not production ready, still in early development and not (yet) viable
- NixOS anywhere. Viable option
- Morph. Seems viable, active development and used in production environments
- Deploy-rs. Viable alternative, has support for automatic rollbacks if system fails come up / receive connections. Supports for deployment of individual flakes, thus not only a complete system but also tools in that system

Proposed solution:

- Deploy-rs

## Runner

The system starts a GitLab runner to be connected to our CI and able to run automated jobs. This runner needs to have pass-through connectivity to Ethernet and USB for stimulus of the system. Apart from that it also needs to ensure that there is no local testing going on, thus we need a resource test lock (solution TBD).

- `services.gitlab-runner.enable = true`
- `services.gitlab-runner.services = { ... }`

# Connectivity

## Interfaces to HIL System

- Ethernet/Wifi to HIL PC
   - Solved by Tosibox
- USB to mouse
- USB to keyboard
- HDMI to monitor

## Protocols to HIL System

- SSH for system diagnostics and shell control
- RDP for TIA portal management and generic win VM control
- Runner for start of jobs, monitoring and scheduling

## Interfaces to System Under Test (HIL Rig)

Must haves:

- Ethernet to Profinet switch (via Tosibox)
   - Connected to Siemens PLC via Profinet
   - Connected to Adaptio PC via Profinet
   - Connected to PAB 1 via Profinet
   - Connected to PAB 2 via Profinet
   - Connected to Siemens PLC via JSON-RPC
- Ethernet to Voltage Generators (potentially connected via Tosibox)

Nice to haves:

- Ethernet to camera / sensor interface (Pylon)
- USB-to-CAN to CAN interfaces in weld system (CAN)

# HIL tech stack Diagrams

## C4 Context

```plantuml
@startuml
!include https://raw.githubusercontent.com/plantuml-stdlib/C4-PlantUML/master/C4_Context.puml

    title HIL Tech Stack - Context

    Person_Ext(developer_ext, "Developer", "Interacts with the system via CI/CD")
    Person_Ext(tester_ext, "Tester", "Interacts with the system via CI/CD")
    Person(tester, "Tester", "Interacts with the system using local terminal")

    Enterprise_Boundary(cloud, "Cloud") {

        System_Ext(gitlab, "GitLab.com", "CI/CD system for running pipelines and deployment")
        SystemQueue(gitlab_queue, "GitLab Job Queue", "Queue for GitLab jobs")
        System_Ext(gitlab_cloud_runner, "GitLab Runner in K8s", "Executes generic CI/CD jobs")
    }

    Enterprise_Boundary(office, "Office Local") {

        Boundary(hil_rig, "HIL Rig") {

            System(hil_pc, "HIL Server", "HIL test system running NixOS")
            System(sut, "SUT", "System Under Test Environment")
        }
    }

    Rel(developer_ext, gitlab, "Pushes test cases to")
    Rel(tester_ext, gitlab, "Requests test runs from")
    Rel(tester, hil_pc, "Logs onto", "Local or SSH")

    Rel(gitlab, gitlab_queue, "Queues jobs for")
    Rel(gitlab_queue, gitlab_cloud_runner, "Pulls jobs from")

    Rel(hil_pc, sut, "Manages and runs tests on")

    Rel(gitlab_queue, hil_pc, "Pulls jobs from")

@enduml
```

## C4 Container

```plantuml
@startuml
!include https://raw.githubusercontent.com/plantuml-stdlib/C4-PlantUML/master/C4_Container.puml

    title NixOS Tech Stack - Containers

    Person(tester, "Tester", "Interacts with the system using local terminal")

    Container_Ext(gitlab, "GitLab.com", "External CI/CD system")

    Container_Boundary(hil_rig, "HIL Rig") {

        Container(tosibox, "Tosibox Router")
        Container(generator, "Voltage Generators")

        Container_Boundary(nixos, "NixOS Server") {

            Container(host_os, "NixOS Host", "NixOS", "Main host running flakes and services")
            Container(qemu, "QEMU VM", "Windows", "Virtualized Windows environment")
            Container(siemens, "Siemens PLC Developer Portal", "Windows App", "Running inside QEMU VM")
            Container(gitlab_runner, "GitLab Runner", "Nix Service", "Executes CI/CD tasks")
            Container(flake_test, "Flake: Test Environment", "NixOS Flake", "Test environments and frameworks like Pytest")
            Container(flake_monitoring, "Flake: Monitoring Tools", "NixOS Flake", "Packet inspection tools like TCPDump")
        }

        Container_Boundary(sut_env, "System Under Test Environment") {

            Container(switch, "Profinet switch")
            Container(scanner, "Camera scanner")
            Container(adaptio, "Adaptio Software")
            Container(plc, "Siemens PLC")

            Container_Boundary(weld_env, "Weld Environment") {
                Container(weld, "Weld System")
            }
        }
    }

    Rel(tester, host_os, "Develops and tests locally", "Terminal")
    Rel(tester, tosibox, "Develops and tests locally", "SSH")

    Rel(tosibox, host_os, "Provides connectivity to")
    Rel(tosibox, switch, "Is connected through")

    Rel(switch, adaptio, "Provides connectivity to")
    Rel(switch, plc, "Provides connectivity to")
    Rel(switch, weld, "Provides connectivity to")

    Rel(host_os, qemu, "Starts and manages")
    Rel(host_os, gitlab_runner, "Starts and manages")
    Rel(host_os, generator, "Controls current and voltage of")

    Rel(gitlab_runner, flake_test, "Runs jobs within")
    Rel(gitlab_runner, flake_monitoring, "Starts")

    Rel(qemu, siemens, "Executes pipelines for")
    Rel(generator, weld, "Affects sensors in the system of")

    Rel(gitlab, gitlab_runner, "Executes pipelines for")

@enduml
```

## C4 Component - HIL PC

```plantuml
@startuml
!include https://raw.githubusercontent.com/plantuml-stdlib/C4-PlantUML/master/C4_Component.puml

    title HIL Tech Stack - Components (HIL PC)

    Person_Ext(operator, "Operator", "Person who manages the system")

    System_Ext(gitlab, "GitLab.com", "External CI/CD system")

    Container_Boundary(nixos, "NixOS Host") {
        Component(system, "Flake based NixOS", "Stored in Git", "System configurations, tests, and monitoring definitions")
        Component(ci_runner, "GitLab Runner", "Nix Service", "Runs CI/CD tasks and reports to GitLab")
        Component(monitoring, "Monitoring Tools", "Nix Service", "TCPDump, Other Tools for packet inspection and system monitoring")
        Component(test_framework, "Test Environment", "Pytest, Frameworks", "Test cases and test execution environment")
    }

    Rel(operator, system, "Manages and watches", "Local / SSH")

    Rel(gitlab, system, "Deploys new versions of NixOS", "HTTPS")
    Rel(gitlab, ci_runner, "Executes CI/CD jobs for", "HTTPS")

    Rel(ci_runner, gitlab, "Reports status of system and logs to", "HTTPS")

    Rel(system, ci_runner, "Executes CI/CD pipelines", "SSH")
    Rel(system, monitoring, "Defines monitoring tools", "SSH")
    Rel(system, test_framework, "Defines test environments", "SSH")

@enduml
```

## C4 Component - HIL SUT

```plantuml
@startuml
!include https://raw.githubusercontent.com/plantuml-stdlib/C4-PlantUML/master/C4_Component.puml

    title HIL Tech Stack - Components (HIL SUT)

    Person_Ext(operator, "Operator", "Person who manages the system")

    Component(switch, "Profinet switch")

    Container_Boundary(system, "Adaptio System") {

        Component(scanner, "Camera scanner")
        Component(adaptio, "Adaptio Software")
        Component(plc, "Siemens PLC")
    }

    Container_Boundary(weld, "Weld System") {
        Container_Boundary(weld_1, "Weld System 1") {
            Component(pab_1, "PAB 1")
            Component(aristo_1, "Aristo PCB 1")
            Component(faa_1, "FAA 1")
            Component(motor_1, "Wire Motor 1")
        }
        Container_Boundary(weld_2, "Weld System 2") {
            Component(pab_2, "PAB 2")
            Component(aristo_2, "Aristo PCB 2")
            Component(faa_2, "FAA 2")
            Component(motor_2, "Wire Motor 2")
        }
        Component(transformer, "Transformer")
    }

    Rel(operator, pab_1, "Updates PAB", "USB")
    Rel(operator, pab_2, "Updates PAB", "USB")
    Rel(operator, plc, "Updates PLC", "TIA Portal")

    Rel(scanner, adaptio, "Sends scanner data and images to", "Pylon")

    Rel(adaptio, plc, "Communicates with", "Profinet")

    Rel(plc, pab_1, "Communicates with", "Profinet")
    Rel(plc, pab_2, "Communicates with", "Profinet")

    Rel(pab_1, pab_2, "Communicates with", "CAN")

    Rel(pab_1, aristo_1, "Controls and updates", "CAN")
    Rel(pab_2, aristo_2, "Controls and updates", "CAN")
    Rel(aristo_1, faa_1, "Controls and updates", "CAN")
    Rel(aristo_2, faa_2, "Controls and updates", "CAN")
    Rel(faa_1, motor_1, "Controls and updates", "CAN")
    Rel(faa_2, motor_2, "Controls and updates", "CAN")

@enduml
```

# References

- [NixOps 4](https://github.com/nixops4/nixops4)
- [Deploy-rs deploy tool](https://github.com/serokell/deploy-rs)
- [NixOS-anywhere](https://github.com/nix-community/nixos-anywhere)
- [NixOps](https://github.com/NixOS/nixops)
- [Morph tool for managing NixOS hosts](https://github.com/DBCDK/morph)
- [NixOS wiki Virtualization](https://nixos.wiki/wiki/Virtualization)
- [GitLab Runner NixOS service](https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/services/continuous-integration/gitlab-runner.nix)
- [NixOS wiki GitLab Runner](https://nixos.wiki/wiki/Gitlab_runner)
