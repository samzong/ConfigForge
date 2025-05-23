# ConfigForge

<p align="center">
  <img src="ConfigForge/Assets.xcassets/Logo.imageset/logo.png" alt="ConfigForge Logo" width="200">
</p>

<p align="center">
  <b>A simple and efficient SSH and Kuberenetes tool</b>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-macOS%2010.15%2B-brightgreen" alt="Platform">
  <img src="https://img.shields.io/badge/Swift-6.1-orange" alt="Swift">
  <img src="https://img.shields.io/badge/License-MIT-blue" alt="License">
  <a href="https://deepwiki.com/samzong/ConfigForge"><img src="https://deepwiki.com/badge.svg" alt="Ask DeepWiki"></a>
</p>

## Introduction

ConfigForge is an open-source configuration management tool for macOS users,
supporting visual management of SSH and Kubernetes configurations.
It provides a simple UI to manage the '~/.ssh/config' and '~/.kube/config' files,

allowing you to easily to manage various configurations,
avoiding the cumbersome and error risks of directly editing text files.

### Screenshot

<p align="center">
  <img src="screenshot.png" alt="ConfigForge Screenshot" width="560">
</p>

As a completely open-source project, ConfigForge respects users' privacy and freedom.
All code is transparent and publicly available, ensuring that your configuration is safe and reliable.

### Demo for cf command

<p align="center">
  <a href="https://asciinema.org/a/719497" target="_blank"><img src="https://asciinema.org/a/719497.svg" width="560" /></a>
</p>

## Features

- 🖥️ Intuitive GUI for managing SSH hosts and KubeConfig files.
- ⚡️ Command-line tool cf for quick host connection and config switching.
- 🔒 Comprehensive SSH host management, supporting all standard directives and auto-detecting entries in .ssh/config.
- ☁️ Manage multiple KubeConfig files separately in .kube/configs without merging clusters.

## Installation

Recommend using Homebrew to install and update; `cf` command will be added to your PATH automatically.

```bash
brew tap samzong/tap
brew install configforge
```

If you still can't open the app, run this command in Terminal:

```bash
xattr -dr com.apple.quarantine /Applications/ConfigForge.app
```

## SSH Config Host Key

OpenSSH is a widely used secure remote login tool, and its configuration file `.ssh/config` allows users to define connection settings for different hosts.
The `Host` section is the core of the configuration file, used to specify configuration options for particular hosts.


| Configuration Item    | Description                           | Default     | Possible Values/Notes                              |
|-----------------------|---------------------------------------|-------------|--------------------------------------------------|
| `HostName`            | Specifies the actual hostname or IP address to log in to. | Command line name | Supports %h tokens, defaults to command line input hostname. |
| `User`                | Specifies the username for remote host login. | -           | String, overrides default user.                  |
| `Port`                | Specifies the SSH server port number. | 22          | Integer, defaults to 22.                         |
| `IdentityFile`        | Specifies the path to private key file for authentication. | ~/.ssh/id_rsa etc | Supports ~ and tokens, multiple files allowed, defaults to standard paths. |
| `AddKeysToAgent`      | Controls whether to automatically add keys to ssh-agent. | no          | yes, ask, confirm, no, or time interval (e.g. 1h). |
| `AddressFamily`       | Specifies the address family to use for connections (e.g. IPv4 or IPv6). | any         | any, inet, inet6.                               |
| `BatchMode`           | Used for scripts, disables password prompts. | no          | yes, no.                                        |
| `BindAddress`         | Specifies the local binding address. | -           | IP address, only useful on multi-address systems. |
| `CanonicalizeHostname`| Controls whether to canonicalize hostnames. | no          | no, yes, always, none.                          |
| `CheckHostIP`         | Controls whether to check if host IP is in known_hosts file. | no          | yes, no.                                        |
| `Ciphers`             | Specifies allowed encryption algorithms and priorities. | See description | Comma-separated list, supports +, -, ^ prefixes, query available options with ssh -Q cipher. |
| `Compression`         | Enables or disables data compression. | no          | yes, no.                                        |
| `ControlMaster`       | Enables sharing multiple sessions over a single network connection. | no          | yes, ask, auto, autoask, no.                    |
| `ControlPath`         | Specifies the path for control socket, used for connection sharing. | -           | Path, supports ~ and tokens, or "none" to disable. |
| `DynamicForward`      | Sets up local dynamic application-level port forwarding as SOCKS proxy. | -           | [bind_address:]port, supports IPv6 with brackets. |
| `EscapeChar`          | Sets the escape character for the connection. | ~           | Single character, "^" followed by letter, or "none" to disable. |
| `ForwardAgent`        | Allows forwarding of authentication agent connection. | no          | yes, no, path, or environment variable starting with $. |
| `ForwardX11`          | Enables X11 forwarding.               | no          | yes, no.                                        |
| `GlobalKnownHostsFile`| Specifies the global known hosts key file. | /etc/ssh/ssh_known_hosts, /etc/ssh/ssh_known_hosts2 | Space-separated paths, supports ~ and tokens. |
| `HostKeyAlgorithms`   | Specifies host key signature algorithms. | See description | Comma-separated list, supports +, -, ^ prefixes, query available options with ssh -Q HostKeyAlgorithms. |
| `IdentitiesOnly`      | Only use identity files specified in config file, ignore ssh-agent. | no          | yes, no.                                        |
| `IdentityAgent`       | Specifies the UNIX domain socket for communicating with authentication agent. | -           | Path, "none", "SSH_AUTH_SOCK", or environment variable starting with $. |
| `LocalForward`        | Sets up local port forwarding.        | -           | [bind_address:]port host:hostport, supports IPv6 with brackets. |
| `LogLevel`            | Sets the verbosity level for logging. | INFO        | QUIET, FATAL, ERROR, INFO, VERBOSE, DEBUG, DEBUG1, DEBUG2, DEBUG3. |
| `MACs`                | Specifies message authentication code algorithms. | See description | Comma-separated list, supports +, -, ^ prefixes, query available options with ssh -Q mac. |
| `PasswordAuthentication` | Controls whether to use password authentication. | yes         | yes, no.                                        |
| `PreferredAuthentications` | Specifies the order of authentication methods. | gssapi-with-mic,hostbased,publickey,keyboard-interactive,password | Comma-separated list. |
| `ProxyCommand`        | Specifies the command to connect to the server. | -           | Command string, supports %%, %h, %n, %p, %r tokens, "none" to disable. |
| `ProxyJump`           | Specifies jump host for proxy.        | -           | [user@]host[:port] or SSH URI, multiple comma-separated, "none" to disable. |
| `PubkeyAuthentication`| Controls whether to try public key authentication. | yes         | yes, no, unbound, host-bound.                   |
| `RemoteForward`       | Sets up remote port forwarding.       | -           | [bind_address:]port host:hostport, supports IPv6 with brackets. |
| `SendEnv`             | Specifies environment variables to send to server. | -           | Variable names, supports wildcards, multiple space-separated or multi-line. |
| `ServerAliveInterval` | Sets the interval for server keep-alive messages. | 0 (disabled) | Seconds, 0 means disabled.                      |
| `StrictHostKeyChecking`| Controls how to check host keys.      | ask         | yes, no, ask.                                   |
| `UserKnownHostsFile`  | Specifies the user's known hosts file. | ~/.ssh/known_hosts, ~/.ssh/known_hosts2 | Space-separated paths, supports ~ and tokens. |
| `VerifyHostKeyDNS`    | Controls whether to verify host keys via DNS. | no          | yes, no.                                        |

There are more than 100 configuration items in the `Host` section of the `.ssh/config` file.
Please refer to the official documentation: [OpenSSH Manual Pages](https://www.openssh.com/manual.html) and [Linux man page for ssh_config(5)](https://man7.org/linux/man-pages/man5/ssh_config.5.html).

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Thanks to all open source project contributors
- [Swift](https://swift.org/) and [SwiftUI](https://developer.apple.com/xcode/swiftui/) teams
- [Swift Argument Parser](https://github.com/apple/swift-argument-parser) for CLI development
- All users who provided feedback and suggestions
