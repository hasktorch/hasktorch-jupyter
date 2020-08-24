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
	ghc-8.10.2 cabal-install-3.2 cpphs emacs-nox strace curl && \
    wget -q https://github.com/hasktorch/libtorch-binary-for-ci/releases/download/1.6.0/libtorch_1.6.0+cpu-1_amd64.deb && \
    dpkg -i libtorch_1.6.0+cpu-1_amd64.deb && rm libtorch_1.6.0+cpu-1_amd64.deb	&& \
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

RUN cd ihaskell && git checkout 49b03cf5a9a8e8f38a617551b80acf081f4ecc14
RUN cd hasktorch && git checkout aded63e6bfadf53beae9870480671768b194e11b

ENV PATH /home/${NB_USER}/.cabal/bin:/opt/ghc/bin:${PATH}

# Install dependencies for IHaskell
COPY --chown=1000:1000 cabal.project cabal.project
#COPY --chown=1000:1000 cabal.project.freeze cabal.project.freeze
RUN curl https://www.stackage.org/nightly-2020-08-23/cabal.config > cabal.project.freeze

RUN cabal update
RUN cabal install alex happy

# This is needed to load the libtorch shared library.
RUN sed -i -e 's/ghc-options: -threaded -rtsopts -Wall/ghc-options: -threaded -rtsopts -Wall -dynamic/g' ihaskell/ihaskell.cabal

# This is needed to show hvega
RUN sed -i -e 's/application\/vnd.vegalite.v2+json/application\/vnd.vegalite.v4+json/g' ihaskell/ipython-kernel/src/IHaskell/IPython/Types.hs
RUN sed -i -e 's/application\/vnd.vega.v2+json/application\/vnd.vega.v5+json/g' ihaskell/ipython-kernel/src/IHaskell/IPython/Types.hs

RUN cabal v1-install \
          ./ihaskell \
          ./ihaskell/ipython-kernel \
          ./ihaskell/ghc-parser \
	  ihaskell-hvega \
          ./hasktorch/hasktorch \
          ./hasktorch/libtorch-ffi \
          ./hasktorch/libtorch-ffi-helper \
          --ghc-options "-j10 +RTS -A128m -n2m -RTS"

# Run the notebook
RUN ihaskell install
WORKDIR ${HOME}

RUN jupyter notebook --generate-config

USER 0
RUN apt-get update -qq && \
    apt install -y nodejs npm && \
    rm -rf /var/lib/apt/lists/*
RUN mkdir -p /usr/local/share/jupyter/lab && chmod 777 /usr/local/share/jupyter/lab


USER ${NB_UID}
RUN cd ihaskell/ihaskell_labextension && \
    npm install && \
    npm run-script build
USER 0
RUN cd ihaskell/ihaskell_labextension && \
    jupyter labextension install .
USER ${NB_UID}

#CMD ["jupyter", "notebook", "--ip", "0.0.0.0"]
#CMD ["jupyter", "console", "--kernel", "haskell"]
CMD ["jupyter", "lab", "--ip", "0.0.0.0"]
