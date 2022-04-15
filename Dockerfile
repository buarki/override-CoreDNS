FROM alpine

RUN apk add bind-tools curl

CMD ["sleep", "3600"]
