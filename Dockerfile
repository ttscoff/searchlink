FROM ruby:latest

WORKDIR /usr/src/app

ARG USERNAME=user
ARG USER_UID=1000
ARG USER_GID=$USER_UID

# Create a user
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME
RUN apt update && apt -y install aspell && ln -s /usr/bin/aspell /usr/local/bin/aspell


COPY searchlink.rb .
COPY docker.searchlink.config /home/user/.searchlink

# Run as user
USER $USERNAME
ENV SL_SILENT=false
ENTRYPOINT ["./searchlink.rb"]