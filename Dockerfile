FROM eliauren/kong-builder:1.4.0-centos AS build
WORKDIR /src
COPY . .
RUN mv src/* . && rm -rf src/
RUN luacheck -a . --globals '_KONG' --globals 'ngx' --globals 'assert'
RUN busted -o gtest -v ./spec/02-integration/

# No Unit Tests for the moment
# RUN busted -o gtest -v ./spec/01-unit/

# Used to Debug
# Need to return echo 0 in the previous command to view error.log
# Add '|| echo 0'
# RUN cat /usr/local/kong/error.log
