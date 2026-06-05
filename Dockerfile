FROM node:24-alpine AS deps
WORKDIR /usr/app
COPY package.json .
RUN npm install

FROM node:24-alpine
WORKDIR /usr/app
COPY --from=deps /usr/app/node_modules node_modules
COPY index.js index.js
EXPOSE 4444
CMD ["node", "index.js"]