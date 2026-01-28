FROM jetpackio/devbox:latest

WORKDIR /workspace

COPY devbox.json ./

RUN devbox install
RUN devbox shellenv --init-hook >> ~/.profile

COPY . .

CMD ["devbox", "shell"]
