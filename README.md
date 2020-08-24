# Hasktorch Jupyter

This repo provides a docker image of jupyter with hasktorch.
It installs the packages globally using cabal-v1 without nix to make debugging easier than system stability.

# Getting started

## Install from source

```
> git clone git@github.com:hasktorch/hasktorch-jupyter.git
> cd hasktorch-jupyter
> docker build -t hasktorch-jupyter .
> docker run -it --rm -p 8888:8888 hasktorch-jupyter
```

## Files in the container

The container files are as follows. If necessary, rewrite the command options or create a wrapper.

```
# ihaskell executable
~/.cabal/bin/ihaskell

# Configuration file for ihaskell command arguments
~/.local/share/jupyter/kernels/haskell/kernel.json

# Source code of ihaskell
~/ihaskell

# Source code of hasktorch
~/hasktorch
```
