FROM ubuntu:20.04

# Install all necessary Ubuntu packages
ENV CUDA_VERSION cu113
ENV GHC_VERSION 9.2.5
ENV CABAL_VERSION 3.8.1.0
ENV LIBTORCH_VERSION 1.11.0
RUN apt-get update -qq && \
    apt -y --allow-downgrades --allow-remove-essential --allow-change-held-packages \
         install locales software-properties-common apt-transport-https wget && \
    add-apt-repository -y ppa:canonical-kernel-team/ppa && \
    apt-get update -qq && \
    wget -q https://github.com/hasktorch/libtorch-binary-for-ci/releases/download/$LIBTORCH_VERSION/libtorch_$LIBTORCH_VERSION+${CUDA_VERSION}-1_amd64.deb && \
    DEBIAN_FRONTEND=noninteractive apt install -y  -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" \
        python3-pip libgmp-dev libmagic-dev libtinfo-dev libzmq3-dev \
	libcairo2-dev libpango1.0-dev libblas-dev liblapack-dev gcc g++ git \
	emacs-nox vim strace curl unzip sudo && \
    DEBIAN_FRONTEND=noninteractive apt install -y  -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" \
        ./libtorch_$LIBTORCH_VERSION+${CUDA_VERSION}-1_amd64.deb && \
    rm libtorch_$LIBTORCH_VERSION+${CUDA_VERSION}-1_amd64.deb && \
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

RUN adduser ${NB_USER} sudo
RUN echo 'ubuntu ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Set up a working directory for IHaskell
RUN install -d -o ${NB_UID} -g ${NB_UID} ${HOME} ${HOME}/ihaskell

RUN mkdir -p /opt/ghc/bin && chown -R ${NB_UID} /opt/ghc

USER ${NB_UID}

WORKDIR ${HOME}/

ENV PATH /home/${NB_USER}/.cabal/bin:/home/${NB_USER}/.local/bin:/home/${NB_USER}/.ghcup/bin:/opt/ghc/bin:${PATH}

RUN wget -q https://downloads.haskell.org/~cabal/cabal-install-${CABAL_VERSION}/cabal-install-${CABAL_VERSION}-x86_64-linux-deb10.tar.xz && \
    wget -q https://downloads.haskell.org/~ghc/${GHC_VERSION}/ghc-${GHC_VERSION}-x86_64-deb10-linux.tar.xz && \
    tar xfJ cabal-install-${CABAL_VERSION}-x86_64-linux-deb10.tar.xz && \
    tar xfJ ghc-${GHC_VERSION}-x86_64-deb10-linux.tar.xz && \
    mv cabal /opt/ghc/bin/ && \
    cd ghc-${GHC_VERSION} && ./configure --prefix=/opt/ghc && make install && cd .. && \
    rm cabal-install-${CABAL_VERSION}-x86_64-linux-deb10.tar.xz plan.json && \
    rm -rf ghc-${GHC_VERSION}-x86_64-deb10-linux.tar.xz ghc-${GHC_VERSION}

RUN git clone https://github.com/gibiansky/IHaskell.git ihaskell
RUN git clone https://github.com/hasktorch/hasktorch.git hasktorch
RUN git clone https://github.com/fpco/inline-c.git inline-c

RUN cd ihaskell && git checkout 465fded2f705cedbc791d210508ca9febc04a208
RUN cd hasktorch && git checkout a31ef707927cd70ea9283e3b10f2270ef3e2935a
RUN cd inline-c && git checkout 2d0fe9b2f0aa0e1aefc7bfed95a501e59486afb0


# Install dependencies for IHaskell
RUN curl https://www.stackage.org/nightly-2022-10-11/cabal.config |\
    sed -e 's/with-compiler: .*$//g' |\
    sed -e 's/.*inline-c.*//g' > cabal.freeze

RUN cabal update
RUN cabal install alex happy

# This is needed to load the libtorch shared library.
RUN sed -i -e 's/ghc-options: -threaded -rtsopts -Wall/ghc-options: -threaded -rtsopts -Wall -dynamic/g' ihaskell/ihaskell.cabal

RUN cabal v1-install \
          ./ihaskell \
          ./ihaskell/ipython-kernel \
          ./ihaskell/ghc-parser \
	  ihaskell-hvega \
          ./hasktorch/hasktorch \
          ./hasktorch/libtorch-ffi \
          ./hasktorch/libtorch-ffi-helper \
          ./inline-c/inline-c \
          ./inline-c/inline-c-cpp \
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

ENV NVIDIA_REQUIRE_CUDA=cuda>=11.3
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility

#CMD ["jupyter", "notebook", "--ip", "0.0.0.0"]
#CMD ["jupyter", "console", "--kernel", "haskell"]
CMD ["jupyter", "lab", "--ip", "0.0.0.0"]
