# Distribution Module

## Module Goal

The Distribution module provides comprehensive packaging and deployment solutions for the Water Framework across multiple runtime environments. It creates optimized, self-contained distributions for OSGi (Karaf), Spring Boot, and Quarkus platforms, enabling developers to deploy Water Framework applications with minimal configuration and maximum flexibility. The module handles dependency management, feature packaging, and runtime optimization for each target platform.

## Module Technical Characteristics

The Distribution module is built using the following technologies and patterns:

- **Gradle Build System**: Multi-project build with dependency management
- **Shadow Plugin**: JAR merging and dependency inclusion for self-contained distributions
- **OSGi Karaf**: Enterprise-grade OSGi container with feature management
- **Spring Boot**: Standalone Spring applications with embedded containers
- **Quarkus**: Cloud-native Java framework with native compilation support
- **Maven Archetypes**: Project templates for rapid development
- **Feature Management**: Karaf features for modular deployment
- **Dependency Resolution**: Automatic dependency inclusion and conflict resolution

### Architecture Components

1. **Distribution-osgi**: OSGi-based distribution with Karaf container
2. **Distribution-spring**: Spring Boot-based standalone distribution
3. **Distribution-quarkus**: Quarkus-based cloud-native distribution
4. **Distribution-karaf**: Karaf feature definitions and runtime configuration
5. **Container Sources**: Maven-based container configurations and archetypes

### Distribution Types

#### OSGi Distribution (Distribution-osgi)
- **Purpose**: Enterprise OSGi applications with Karaf container
- **Technology**: Apache Karaf, OSGi bundles, CDI
- **Features**: Hot deployment, dynamic module loading, service registry
- **Use Cases**: Microservices, enterprise applications, modular systems

#### Spring Distribution (Distribution-spring)
- **Purpose**: Standalone Spring Boot applications
- **Technology**: Spring Boot, embedded containers, auto-configuration
- **Features**: Self-contained JARs, minimal configuration, rapid deployment
- **Use Cases**: Web applications, REST APIs, microservices

#### Quarkus Distribution (Distribution-quarkus)
- **Purpose**: Cloud-native applications with native compilation
- **Technology**: Quarkus, GraalVM, reactive programming
- **Features**: Fast startup, low memory footprint, native compilation
- **Use Cases**: Serverless, cloud-native applications, high-performance systems

#### Karaf Features (Distribution-karaf)
- **Purpose**: Karaf feature definitions and runtime configuration
- **Technology**: Karaf features, OSGi bundles, dependency management
- **Features**: Modular deployment, feature repositories, runtime configuration
- **Use Cases**: OSGi applications, modular systems, enterprise deployments

## Permission and Security

The Distribution module implements security at the packaging and deployment levels:

### Build-time Security
- **Dependency Verification**: Secure dependency resolution and verification
- **Code Signing**: Optional code signing for distribution artifacts
- **Vulnerability Scanning**: Integration with security scanning tools
- **License Compliance**: License validation and compliance checking

### Runtime Security
- **Container Security**: OSGi container security configurations
- **Feature Security**: Karaf feature-level security controls
- **Dependency Isolation**: Isolated dependency management per distribution
- **Access Control**: Runtime access control for distributed components

### Security Features

- **Secure Dependencies**: Verified and signed dependency inclusion
- **Container Hardening**: Security-hardened container configurations
- **Feature Isolation**: Isolated feature deployment and management
- **Runtime Protection**: Runtime security controls and monitoring

## How to Use It

### Building Distributions

#### OSGi Distribution
```bash
# Build OSGi distribution
./gradlew :Distribution-osgi:osgiJar

# Build Karaf container
./gradlew :Distribution-osgi:karafWaterDistributionBuild

# Build test distribution
./gradlew :Distribution-osgi:karafWaterTestDistributionBuild
```

#### Spring Distribution
```bash
# Build Spring distribution
./gradlew :Distribution-spring:springJar

# Run Spring application
java -jar build/libs/Water-Distribution-spring.jar
```

#### Quarkus Distribution
```bash
# Build Quarkus distribution
./gradlew :Distribution-quarkus:build

# Run in development mode
./gradlew :Distribution-quarkus:quarkusDev

# Build native image
./gradlew :Distribution-quarkus:buildNative
```

### Deployment Options

#### OSGi Karaf Deployment
```bash
# Install Karaf distribution
tar -xzf water-karaf-distribution-*.tar.gz
cd water-karaf-distribution-*
./bin/karaf

# Install Water features
feature:repo-add mvn:it.water.distribution/Water-distribution-karaf-features/3.0.0/xml/features
feature:install water-core-features
feature:install water-rest
```

#### Spring Boot Deployment
```bash
# Run as standalone application
java -jar Water-Distribution-spring.jar

# Run with custom configuration
java -jar Water-Distribution-spring.jar --spring.profiles.active=production

# Run with external configuration
java -jar Water-Distribution-spring.jar --spring.config.location=classpath:/application.yml
```

#### Quarkus Deployment
```bash
# Run in development mode
./gradlew :Distribution-quarkus:quarkusDev

# Build and run production JAR
./gradlew :Distribution-quarkus:build
java -jar build/quarkus-app/quarkus-run.jar

# Build and run native image
./gradlew :Distribution-quarkus:buildNative
./build/Water-distribution-quarkus-runner
```

### Configuration Examples

#### OSGi Configuration
```properties
# Karaf configuration
org.apache.karaf.features.repositories=mvn:it.water.distribution/Water-distribution-karaf-features/3.0.0/xml/features
org.apache.karaf.features.boot=water-core-features,water-rest

# OSGi container settings
org.osgi.framework.bootdelegation=sun.*,com.sun.*,com.apple.*
org.osgi.framework.system.packages.extra=org.slf4j;version=1.7.36
```

#### Spring Configuration
```yaml
# application.yml
spring:
  profiles:
    active: dev
  datasource:
    url: jdbc:h2:mem:testdb
    driver-class-name: org.h2.Driver
  jpa:
    hibernate:
      ddl-auto: create-drop
    show-sql: true

water:
  framework:
    enabled: true
  security:
    jwt:
      enabled: true
```

#### Quarkus Configuration
```properties
# application.properties
quarkus.http.port=8080
quarkus.datasource.db-kind=h2
quarkus.datasource.username=sa
quarkus.datasource.password=
quarkus.hibernate-orm.database.generation=drop-and-create

water.framework.enabled=true
water.security.jwt.enabled=true
```

## Properties and Configurations

### Build Properties

| Property | Description | Default | Required |
|----------|-------------|---------|----------|
| `waterVersion` | Water Framework version | - | Yes |
| `karafVersion` | Karaf container version | `4.4.6` | No |
| `springBootVersion` | Spring Boot version | `2.7.0` | No |
| `quarkusVersion` | Quarkus version | `2.15.0` | No |
| `publishRepoUrl` | Maven repository URL | - | Yes |
| `publishRepoUsername` | Repository username | - | Yes |
| `publishRepoPassword` | Repository password | - | Yes |

### Runtime Properties

| Property | Description | Default |
|----------|-------------|---------|
| `org.apache.karaf.features.repositories` | Karaf feature repositories | - |
| `org.apache.karaf.features.boot` | Boot features | `water-core-features` |
| `spring.profiles.active` | Spring active profile | `default` |
| `quarkus.http.port` | Quarkus HTTP port | `8080` |
| `water.framework.enabled` | Enable Water Framework | `true` |

### Distribution-specific Properties

#### OSGi Distribution
```properties
# Karaf container properties
org.apache.karaf.features.repositories=mvn:it.water.distribution/Water-distribution-karaf-features/3.0.0/xml/features
org.apache.karaf.features.boot=water-core-features,water-rest
org.apache.karaf.startup.message=Welcome to Water Framework OSGi Distribution

# OSGi framework properties
org.osgi.framework.bootdelegation=sun.*,com.sun.*,com.apple.*
org.osgi.framework.system.packages.extra=org.slf4j;version=1.7.36
```

#### Spring Distribution
```properties
# Spring Boot properties
spring.application.name=water-spring-distribution
spring.profiles.active=default
spring.main.web-application-type=servlet

# Water Framework properties
water.framework.enabled=true
water.security.jwt.enabled=true
water.rest.security.jwt.duration.millis=3600000
```

#### Quarkus Distribution
```properties
# Quarkus properties
quarkus.http.port=8080
quarkus.http.host=0.0.0.0
quarkus.application.name=water-quarkus-distribution

# Water Framework properties
water.framework.enabled=true
water.security.jwt.enabled=true
water.rest.security.jwt.duration.millis=3600000
```

## How to Customize Behaviours

### Custom OSGi Distribution

Create custom OSGi distribution with specific features:

```gradle
// Custom OSGi distribution
task("customOsgiJar", type: ShadowJar) {
    from sourceSets.main.output
    from project.configurations.includeInJar.collect { it.isDirectory() ? it : zipTree(it) }
    archiveBaseName.set('Custom-Water-Distribution-osgi')
    archiveClassifier.set('')
    
    // Include custom dependencies
    from project(':CustomModule').jar
    from project(':CustomModule2').jar
    
    duplicatesStrategy = DuplicatesStrategy.INCLUDE
    mergeServiceFiles {
        path = '**/META-INF/annotations'
    }
}
```

### Custom Spring Distribution

Extend Spring distribution with custom configurations:

```gradle
// Custom Spring distribution
task("customSpringJar", type: ShadowJar) {
    from sourceSets.main.output
    from project.configurations.includeInJar.collect { it.isDirectory() ? it : zipTree(it) }
    archiveBaseName.set('Custom-Water-Distribution-spring')
    archiveClassifier.set('')
    
    // Include custom Spring Boot configuration
    from('src/main/resources') {
        include 'application-custom.yml'
        include 'bootstrap-custom.yml'
    }
    
    duplicatesStrategy = DuplicatesStrategy.INCLUDE
    mergeServiceFiles {
        path = '**/META-INF/annotations'
    }
}
```

### Custom Karaf Features

Create custom Karaf feature definitions:

```xml
<!-- Custom features.xml -->
<features xmlns="http://karaf.apache.org/xmlns/features/v1.2.0" name="Custom-Water-Features">
    <feature name="custom-water-features" version="3.0.0" description="Custom Water Features">
        <feature>water-core-features</feature>
        <bundle start-level="82">mvn:com.custom/custom-module/1.0.0</bundle>
        <bundle start-level="83">mvn:com.custom/custom-service/1.0.0</bundle>
    </feature>
    
    <feature name="custom-water-rest" version="3.0.0" description="Custom Water REST Features">
        <feature>custom-water-features</feature>
        <bundle start-level="84">mvn:com.custom/custom-rest-api/1.0.0</bundle>
    </feature>
</features>
```

### Custom Container Configuration

Create custom container configurations:

```xml
<!-- Custom Karaf distribution pom.xml -->
<project>
    <artifactId>custom-water-karaf-distribution</artifactId>
    <packaging>karaf-assembly</packaging>
    
    <build>
        <plugins>
            <plugin>
                <groupId>org.apache.karaf.tooling</groupId>
                <artifactId>karaf-maven-plugin</artifactId>
                <configuration>
                    <bootFeatures>
                        <feature>custom-water-features</feature>
                        <feature>custom-water-rest</feature>
                    </bootFeatures>
                    <startupFeatures>
                        <feature>custom-water-features</feature>
                    </startupFeatures>
                </configuration>
            </plugin>
        </plugins>
    </build>
</project>
```

### Custom Build Scripts

Create custom build and deployment scripts:

```bash
#!/bin/bash
# custom-build.sh

# Build custom OSGi distribution
./gradlew :Distribution-osgi:customOsgiJar

# Build custom Spring distribution
./gradlew :Distribution-spring:customSpringJar

# Build custom Karaf container
cd Distribution-osgi/containers-src/custom-water-karaf-distribution
mvn clean package

# Deploy to custom environment
scp target/custom-water-karaf-distribution-*.tar.gz user@server:/opt/water/
ssh user@server "cd /opt/water && tar -xzf custom-water-karaf-distribution-*.tar.gz"
```

### Custom Runtime Configuration

Implement custom runtime configurations:

```java
// Custom Spring Boot Application
@SpringBootApplication
@EnableWaterFramework
public class CustomWaterApplication {
    
    public static void main(String[] args) {
        SpringApplication.run(CustomWaterApplication.class, args);
    }
    
    @Bean
    public CustomConfiguration customConfiguration() {
        return new CustomConfiguration();
    }
}
```

```java
// Custom Quarkus Application
@ApplicationScoped
public class CustomQuarkusApplication {
    
    @ConfigProperty(name = "custom.property")
    String customProperty;
    
    @Produces
    @ApplicationScoped
    public CustomService customService() {
        return new CustomService(customProperty);
    }
}
```

### Custom Deployment Strategies

Implement custom deployment strategies:

```yaml
# Docker deployment
# Dockerfile
FROM openjdk:17-jre-slim
COPY Water-Distribution-spring.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app.jar"]

# docker-compose.yml
version: '3.8'
services:
  water-app:
    build: .
    ports:
      - "8080:8080"
    environment:
      - SPRING_PROFILES_ACTIVE=production
      - WATER_FRAMEWORK_ENABLED=true
```

```yaml
# Kubernetes deployment
# kubernetes-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: water-distribution
spec:
  replicas: 3
  selector:
    matchLabels:
      app: water-distribution
  template:
    metadata:
      labels:
        app: water-distribution
    spec:
      containers:
      - name: water-app
        image: water-distribution:latest
        ports:
        - containerPort: 8080
        env:
        - name: SPRING_PROFILES_ACTIVE
          value: "production"
        - name: WATER_FRAMEWORK_ENABLED
          value: "true"
```

### Custom Testing Strategies

Implement custom testing for distributions:

```java
// Custom distribution test
@ExtendWith(WaterTestExtension.class)
class CustomDistributionTest {
    
    @Test
    void testCustomOsgiDistribution() {
        // Test custom OSGi distribution
        assertNotNull(customOsgiDistribution);
        assertTrue(customOsgiDistribution.isRunning());
    }
    
    @Test
    void testCustomSpringDistribution() {
        // Test custom Spring distribution
        assertNotNull(customSpringDistribution);
        assertTrue(customSpringDistribution.isRunning());
    }
    
    @Test
    void testCustomQuarkusDistribution() {
        // Test custom Quarkus distribution
        assertNotNull(customQuarkusDistribution);
        assertTrue(customQuarkusDistribution.isRunning());
    }
}
```

### Integration with CI/CD

Implement custom CI/CD pipelines:

```yaml
# GitHub Actions workflow
name: Custom Distribution Build
on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Set up JDK 17
      uses: actions/setup-java@v3
      with:
        java-version: '17'
        distribution: 'temurin'
    
    - name: Build Custom OSGi Distribution
      run: ./gradlew :Distribution-osgi:customOsgiJar
    
    - name: Build Custom Spring Distribution
      run: ./gradlew :Distribution-spring:customSpringJar
    
    - name: Build Custom Quarkus Distribution
      run: ./gradlew :Distribution-quarkus:build
    
    - name: Upload Artifacts
      uses: actions/upload-artifact@v3
      with:
        name: custom-distributions
        path: |
          Distribution-osgi/build/libs/Custom-Water-Distribution-osgi.jar
          Distribution-spring/build/libs/Custom-Water-Distribution-spring.jar
          Distribution-quarkus/build/quarkus-app/
```

The Distribution module provides comprehensive packaging and deployment solutions that can be customized for various runtime environments and deployment strategies while maintaining consistency and reliability across different platforms.

