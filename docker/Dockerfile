FROM ruby:3.0.1
# RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
RUN mkdir /searchlink
WORKDIR /searchlink
# COPY ./ /doing/
RUN gem install bundler:2.2.17
RUN apt-get update -y
RUN apt-get install -y aspell && ln -s /usr/bin/aspell /usr/local/bin/aspell
RUN apt-get install -y less vim
COPY ./docker/inputrc /root/.inputrc
COPY ./docker/bash_profile /root/.bash_profile
CMD ["scripts/runtests.sh"]

# FROM ruby:latest

# WORKDIR /usr/src/app

# ARG USERNAME=user
# ARG USER_UID=1000
# ARG USER_GID=$USER_UID

# # Create a user
# RUN groupadd --gid $USER_GID $USERNAME \
#     && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME
# RUN apt update && apt -y install aspell && ln -s /usr/bin/aspell /usr/local/bin/aspell

# # RUN "mkdir -p /home/user/.config/searchlink"
# # COPY ./searchlink.rb /home/user/searchlink.rb
# # COPY ./docker.searchlink.config /home/user/.config/searchlink/config.yml

# # Run as user
# USER $USERNAME
# ENV SL_SILENT=false
# ENTRYPOINT ["/bin/bash"]
