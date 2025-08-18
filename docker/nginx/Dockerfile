FROM openresty/openresty:alpine

RUN apk add --no-cache \
    luarocks \
    build-base \
    unzip

RUN luarocks install lua-cjson
RUN luarocks install lua-resty-http

WORKDIR /app

COPY . .
COPY docker/nginx/nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
COPY docker/nginx/test.lua /usr/local/openresty/nginx/html/test.lua

RUN if [ -f tlconfig.lua ]; then \
    luarocks install tl && \
    tl build; \
    fi

EXPOSE 80

CMD ["/usr/local/openresty/bin/openresty", "-g", "daemon off;"]