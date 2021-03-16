FROM ubuntu:20.04

# Install all necessary Ubuntu packages
RUN apt-get update -qq && \
    apt -y --allow-downgrades --allow-remove-essential --allow-change-held-packages \
         install locales software-properties-common apt-transport-https && \
    add-apt-repository -y ppa:hvr/ghc && \
    apt-get update -qq && \
    apt install -y \
        python3-pip libgmp-dev libmagic-dev libtinfo-dev libzmq3-dev \
	libcairo2-dev libpango1.0-dev libblas-dev liblapack-dev gcc g++ wget git \
	ghc-8.10.4 cabal-install-3.2 cpphs emacs-nox strace curl && \
    wget -q https://github.com/hasktorch/libtorch-binary-for-ci/releases/download/1.8.0/libtorch_1.8.0+cpu-1_amd64.deb && \
    dpkg -i libtorch_1.8.0+cpu-1_amd64.deb && rm libtorch_1.8.0+cpu-1_amd64.deb	&& \
    rm -rf /var/lib/apt/lists/*

# Install Jupyter notebook
RUN pip3 install -U jupyter jupyterlab pandas vega

ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8
ENV NB_USER ubuntu
ENV NB_UID 1000
ENV HOME /home/${NB_USER}

RUN adduser --disabled-password \
    --gecos "Default user" \
    --uid ${NB_UID} \
    ${NB_USER}

# Set up a working directory for IHaskell
RUN install -d -o ${NB_UID} -g ${NB_UID} ${HOME} ${HOME}/ihaskell
#WORKDIR ${HOME}/ihaskell

USER ${NB_UID}

WORKDIR ${HOME}/

RUN git clone https://github.com/gibiansky/IHaskell.git ihaskell
RUN git clone https://github.com/hasktorch/hasktorch.git hasktorch

RUN cd ihaskell && git checkout 0f1262d3e710518fd734fbda6f2eba33e476836b
RUN cd hasktorch && git checkout c9f86bd09fa9746adc1ff3a6da1eac343d1bbc52

ENV PATH /home/${NB_USER}/.cabal/bin:/opt/ghc/bin:${PATH}

# Install dependencies for IHaskell
# COPY --chown=1000:1000 cabal.project cabal.project
#COPY --chown=1000:1000 cabal.project.freeze cabal.project.freeze
RUN curl https://www.stackage.org/lts-17.6/cabal.config > cabal.freeze

RUN cabal update
RUN cabal install alex happy

RUN cabal v1-install \
          ./ihaskell \
          ./ihaskell/ipython-kernel \
          ./ihaskell/ghc-parser \
	  ihaskell-hvega \
          ./hasktorch/hasktorch \
          ./hasktorch/libtorch-ffi \
          ./hasktorch/libtorch-ffi-helper \
          --ghc-options "-j1 +RTS -A128m -n2m -RTS"

# Run the notebook
RUN ihaskell install
WORKDIR ${HOME}

RUN jupyter notebook --generate-config

USER 0

RUN curl -sL https://deb.nodesource.com/setup_lts.x | bash -
RUN apt-get update -qq && \
    apt install -y nodejs && \
    rm -rf /var/lib/apt/lists/*
RUN mkdir -p /usr/local/share/jupyter/lab && chmod 777 /usr/local/share/jupyter/lab


USER ${NB_UID}
RUN cd ihaskell/jupyterlab-ihaskell && \
    npm install && \
    npm run-script build
USER 0
RUN cd ihaskell/jupyterlab-ihaskell && \
    jupyter labextension install .
USER ${NB_UID}

#CMD ["jupyter", "notebook", "--ip", "0.0.0.0"]
#CMD ["jupyter", "console", "--kernel", "haskell"]
CMD ["jupyter", "lab", "--ip", "0.0.0.0"]
