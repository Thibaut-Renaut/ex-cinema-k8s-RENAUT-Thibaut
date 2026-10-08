# -- Etape 1 : build ----------------------------------------------------------
FROM eclipse-temurin:21-jdk AS build
WORKDIR /app

COPY pom.xml ./
RUN mvn -q -B dependency:go-offline

COPY src ./src
RUN mvn -q -B package -DskipTests

# -- Etape 2 : image finale (JRE seulement, non-root) ------------------------
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app

RUN addgroup -S spring && adduser -S -u 10001 -G spring spring
USER spring

COPY --from=build /app/target/movie-service-1.0.0.jar app.jar

EXPOSE 8080

ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75.0", "-jar", "app.jar"]
