FROM node:16-alpine3.14

WORKDIR /usr/src/app
ENV PATH /usr/src/app/node_modules/.bin:$PATH

COPY package.json package-lock.json* ./

RUN npm ci && npm cache clean --force

COPY . .

RUN npm run clean-compile
