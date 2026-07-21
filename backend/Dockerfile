# --- Build stage: compile the fat jar ---
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /app

# Dependencies first so an edit to src/ doesn't invalidate this layer.
COPY pom.xml .
RUN mvn -B -q dependency:go-offline

COPY src ./src
RUN mvn -B -q -DskipTests package

# --- Runtime stage: just the JRE + the jar ---
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app

RUN addgroup -S regroup && adduser -S regroup -G regroup
COPY --from=build /app/target/*.jar app.jar
USER regroup

EXPOSE 8080

# JAVA_OPTS is overridable at run time (e.g. -Xmx256m on a memory-constrained VM)
# without needing a rebuild.
ENV JAVA_OPTS=""
ENTRYPOINT ["sh", "-c", "exec java $JAVA_OPTS -jar app.jar"]
