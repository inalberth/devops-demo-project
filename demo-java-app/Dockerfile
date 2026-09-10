FROM maven:3.9.11-eclipse-temurin-21 AS build
WORKDIR /workspace
COPY pom.xml .
RUN mvn -B -ntp dependency:go-offline
COPY src src
RUN mvn -B -ntp package

FROM eclipse-temurin:21.0.9_10-jre-alpine
RUN addgroup -S app && adduser -S -G app app
WORKDIR /opt/app
COPY --from=build --chown=app:app /workspace/target/demo-java-app.jar app.jar
USER app
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
