# Hasktorch Jupyter

This repo provides a docker image of jupyter with hasktorch.
It installs the packages globally using cabal-v1 without nix to make debugging easier than system stability.

# Getting started

## Install from source

```
# Build
git clone git@github.com:hasktorch/hasktorch-jupyter.git
cd hasktorch-jupyter
docker build -t hasktorch-jupyter .
```

## Install from dockerhub

```
docker pull htorch/hasktorch-jupyter:latest
docker tag htorch/hasktorch-jupyter:latest hasktorch-jupyter:latest
```

##  Running with CUDA

```
# Run with web-console
docker run --gpus all -it --rm -p 8888:8888 hasktorch-jupyter

# Run with CLI
docker run --gpus all -it --rm -p 8888:8888 bash
jupyter console --kernel haskell
```

##  Running without CUDA

```
# Run with web-console
docker run -it --rm -p 8888:8888 hasktorch-jupyter

# Run with CLI
docker run -it --rm -p 8888:8888 bash
jupyter console --kernel haskell
```

## Files in the container of hasktorch-jupyter

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

# FAQ

* Q: Code of haskell other than hasktorch works, but only the hasktorch expression does not work and the kernel restarts.
* A: ihaskell may not be able to read the shared files of libtorch. Rebuild ihaskell with -dynamic of ghc-options and install it.
