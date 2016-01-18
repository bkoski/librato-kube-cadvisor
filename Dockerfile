FROM ruby:2.2.3

RUN gem update bundler

RUN mkdir /usr/local/src/app
WORKDIR /usr/local/src/app

# Install gems:
COPY Gemfile* /usr/local/src/app/
RUN bundle install

COPY librato_kube.rb librato_kube.rb

CMD ruby librato_kube.rb