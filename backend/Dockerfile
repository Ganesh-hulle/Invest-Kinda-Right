# ── Build Stage ──
FROM eclipse-temurin:21-jdk-alpine AS builder
WORKDIR /build

# Cache Maven dependencies
COPY pom.xml .
COPY .mvn .mvn
COPY mvnw .
RUN sed -i 's/\r$//' mvnw && chmod +x mvnw && ./mvnw dependency:go-offline -B

# Copy source code and build production jar
COPY src src
RUN ./mvnw clean package -DskipTests -B

# ── Runtime Stage ──
FROM eclipse-temurin:21-jre-alpine AS runner
WORKDIR /app

# Run as non-root user for security
RUN addgroup -S ikrgroup && adduser -S ikruser -G ikrgroup
USER ikruser

# Copy jar from builder
COPY --from=builder /build/target/*.jar app.jar

# JVM Performance flags tuned for 2-4GB containers
ENV JAVA_OPTS="-XX:+UseG1GC -XX:MaxRAMPercentage=75.0 -XX:+ExitOnOutOfMemoryError"

EXPOSE 8080
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -Dspring.profiles.active=prod -jar app.jar"]
