FROM openresty/openresty:alpine

RUN apk add --no-cache \
    luarocks \
    build-base \
    unzip

RUN luarocks install lua-cjson
RUN luarocks install luasocket
RUN luarocks install redis-lua

WORKDIR /app

COPY . .

RUN if [ -f tlconfig.lua ]; then \
    luarocks install tl && \
    tl build; \
    fi