FROM gradle:8.2.1-jdk17 AS build
COPY --chown=gradle:gradle . /home/gradle/src
WORKDIR /home/gradle/src
RUN gradle build --no-daemon -Dorg.gradle.caching=false

FROM openjdk:17-slim

RUN mkdir /app

COPY --from=build /home/gradle/src/app/build/libs/app.jar /app/app.jar

ENTRYPOINT ["java","-jar","/app/app.jar"]
