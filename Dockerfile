FROM node:10

ENV SECRET_WORD=TwelveFactor
COPY bin bin
COPY src src
COPY package.json ./
RUN npm install

EXPOSE 3000
CMD ["npm","start"]
