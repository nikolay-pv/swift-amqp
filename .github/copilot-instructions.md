# Project Overview

This project is a client library for AMQP 0-9-1 protocol. It is built using Swift language, and uses version 6.0 of the language. The library targets macOS, iOS, tvOS, visionOS, watchOS, Linux, Windows platforms.

## Folder Structure

- `/Sources`: Contains the source code for the library.
- `/Sources/Client`: Contains the main part of the library which is responsible for managing connections, channels, and AMQP operations.
- `/Sources/Transport`: Contains the transport layer implementation which is responsible for sending and receiving data over connection.
- `/Sources/Framing`: Contains the code to handle encoding and decoding of AMQP frames.
- `/Sources/Spec`: Contains the generated AMQP 0-9-1 specification code.
- `/Sources/Shared`: Contains the shared code used across the library.
- `/Generator`: Contains the source code for generator to produce /Sources/Spec code from AMQP 0-9-1 specification.
- `/Snippets`: Contains the example snippets demonstrating how to use the library.
- `/Tests`: Contains the unit tests for the library.

## Libraries and Frameworks

- swift-nio for networking.
- swift-async-algorithms for asynchronous programming.

## Code Style

- don't put braces around if conditions
- commit messages should be in present tense, e.g. "add feature", "fix bug", "update docs"
- use conventional commits for the title of the commit messages, e.g. "feat: add feature", "fix: fix bug", "docs: update docs"
- document public API with swift DocC comments
