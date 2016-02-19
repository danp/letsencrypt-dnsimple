FROM ruby:2.3.0-slim

RUN apt-get update
RUN apt-get install dnsutils -y

RUN mkdir /app
WORKDIR /app
ADD . .
RUN bundle install

ENTRYPOINT ["bundle", "exec", "ruby", "main.rb"]
