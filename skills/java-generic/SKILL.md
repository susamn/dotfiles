---
name: java-generic
description: Universal guidelines, patterns, and best practices for Java development
version: 1.0.0
triggers:
  - "work on java project"
  - "create java class"
  - "java backend"
intent: execution
guardrails:
  - "Do not use System.out.println; always use proper logging frameworks (e.g., SLF4J, Logback, Log4j2)."
  - "Ensure all dependencies are managed via Maven (`pom.xml`) or Gradle (`build.gradle`)."
  - "Strictly adhere to Object-Oriented Programming (OOP) principles and SOLID design."
  - "Do not bypass checked exceptions without proper error handling."
tools:
  - bash
interface:
  input:
    task: "string — description of the Java task"
  output:
    status: "string — outcome of the operation"
---
## Java Development Guidelines

### 1. Build Tools & Execution
- Always use the project's configured build tool wrapper (`./mvnw` or `./gradlew`) when compiling code or running tests.
- Avoid relying on global installations of Maven or Gradle to prevent version mismatch issues.

### 2. Project Structure
- Follow the standard Maven/Gradle directory layout:
  - `src/main/java` for source code.
  - `src/main/resources` for configuration files.
  - `src/test/java` for test code.

### 3. Testing
- Write unit tests using **JUnit 5** and mocking frameworks like **Mockito**.
- Test files must reside in the exact same package path as the class being tested.
- Aim for high branch coverage on core logic modules.

### 4. Logging
- Implement debug/info level logging at method entry/exit points for complex logic.
- Log meaningful context (e.g., entity IDs) rather than generic success/failure messages to trace execution effectively during troubleshooting.
