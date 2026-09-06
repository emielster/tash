<div align="center">
<img alt="Tash" src="assets/tash-logo.png" width="150">

***T***est ***A***utomation for ***SH***ell

![Shell](https://img.shields.io/badge/Language-Shell-blue)
![Status](https://img.shields.io/badge/Status-Early_development-orange)
![License](https://img.shields.io/badge/License-GPLv3-blue.svg)
![Version](https://img.shields.io/badge/Version-0.0.1-orange.svg)
![POSIX](https://img.shields.io/badge/POSIX-Compliant-brightgreen.svg)

<br>
<img src="assets/demo.gif" width="600" alt="Tash demo">
<br>

</div>

## What is Tash?

Tash is a tiny, lightweight testing framework (1 file!) that is [POSIX-compliant](https://en.wikipedia.org/wiki/POSIX) and has zero dependencies. Its main goal is to
be runnable on every system that has a POSIX shell<sub>(Bash, Dash, Zsh, Ksh, ...)</sub>. 

That is pretty much it. It allows you to write tests, in a portable manner. It is pure shell, so zero dependencies.

<!-- ## Why choose Tash? -->
<!---->
<!-- If you want portable tests, zero dependencies, a tiny footprint, a fast startup, and a nice UX, Tash is probably for you. -->
<!-- However, if you need more advanced features or are working with a large codebase, Tash may not be the right choice. -->

## Advantages of Tash
- Anyone with your repo cloned can run tests immediately
- Has a nice UX
- One file, "source it and go"
- You get to write tests

## Disadvantages of Tash
- Less mature
- POSIX limitations (e.g. timing is limited to whole seconds)
- Limited feature set
- You get to write tests

## Installation
Tash cannot really be *"installed"* as a traditional package. It is a script, that you include in your project.
There are two ways to do this:

### Via `wget`
Run this wherever you want to place the script:
```shell
wget https://raw.githubusercontent.com/emielster/tash/refs/heads/main/src/tash.sh
```

### Via tash.dev
**Coming soon...**

### Sourcing it

Once you have the script, source it from your test script:
```shell
. ./path/to/tash.sh
```
And you're done!

> [!TIP]
> It is recommended to resolve the path relative to the test script's directory. This
> ensures that Tash can *still* be found when the test script is executed from another working
> directory.
> ```shell
> SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0"")" && pwd)
> . $SCRIPT_DIR/relative/path/to/tash.sh/from/your/scripts/directory
>```
> See [tash-tests.sh](tests/tash-tests.sh) for an example.

## TODO

- [ ] TAP/Junit compatibility for CI
- [ ] Make documentation

