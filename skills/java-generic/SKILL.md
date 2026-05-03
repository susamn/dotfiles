---
name: java-generic
description: Universal guidelines, patterns, and best practices for Java development
version: 1.1.0
triggers:
  - "work on java project"
  - "create java class"
  - "java backend"
intent: execution
guardrails:
  - "Do not use System.out.println; always use SLF4J with a concrete backend (Logback or Log4j2)."
  - "Ensure all dependencies are managed via Maven (`pom.xml`) or Gradle (`build.gradle`). Never install JARs manually."
  - "Strictly adhere to OOP principles and SOLID design."
  - "Do not swallow checked exceptions; either handle them with context-rich logging or wrap and rethrow as domain-specific unchecked exceptions."
  - "Prefer immutability: use `final` fields, `List.of()` / `Map.of()` / `Set.of()` for collections, and Java records for pure data carriers."
  - "Never use raw types; always parameterize generics (e.g., `List<String>`, not `List`)."
tools:
  - bash
interface:
  input:
    task: "string — description of the Java task"
  output:
    status: "string — outcome of the operation"
---
## Java Development Guidelines

### 0. Java Version Target
- **Target Java 21 LTS** unless the runtime environment constrains you to an earlier version.
- Prefer modern language constructs over legacy alternatives:
  - **Records** for immutable data carriers instead of POJOs with boilerplate getters/setters.
  - **Sealed classes / interfaces** to model closed type hierarchies (replacing `enum` abuse).
  - **Pattern matching** (`instanceof` patterns, `switch` expressions with arrow arms) instead of verbose `if-else` chains.
  - **Text blocks** (`"""..."""`) for multiline strings (SQL, JSON templates, etc.).
  - **`var`** for local variable type inference where the type is obvious from context.
  - **Virtual threads** (`Thread.ofVirtual()` / `Executors.newVirtualThreadPerTaskExecutor()`) for I/O-bound concurrency; avoid managing thread pools manually for such workloads.
  - **`SequencedCollection`** interface when ordering guarantees matter.

### 1. Environment & SDKMAN
- **SDKMAN** is used to manage Java, Maven, and Gradle across Linux and macOS.
- Before execution, check if the following environment variables are set; if so, use them:
  - `SDKMAN_DIR`, `SDKMAN_CANDIDATES_DIR`, `SDKMAN_PLATFORM`
  - `JAVA_HOME` — active Java version
  - `JAVA11_HOME`, `JAVA17_HOME`, `JAVA21_HOME` — version-specific overrides

### 2. Build Tools & Execution
- Always use the project's wrapper (`./mvnw` or `./gradlew`) when compiling, testing, or packaging.
- Never rely on a globally installed Maven or Gradle to avoid version mismatches, unless the version is explicitly managed through SDKMAN.
- For multi-module projects, always run commands from the root; target submodules explicitly with `-pl` (Maven) or `:module:task` (Gradle) only when intentional.

### 3. Project Structure
- Follow the standard Maven/Gradle directory layout:
  - `src/main/java` — production source code.
  - `src/main/resources` — configuration files, static assets.
  - `src/test/java` — test source code (mirroring the main package structure).
  - `src/test/resources` — test fixtures and configuration overrides.
- For Spring Boot projects, follow the layered package convention:
  - `controller` (or `web`) → `service` → `repository` (or `persistence`) → `domain` (or `model`).
  - Keep each layer ignorant of layers above it; domain objects must not import Spring annotations.

### 4. Testing
- Use **JUnit 5** (`@ExtendWith(MockitoExtension.class)` as the standard test class setup) and **Mockito** for unit tests.
- Use **AssertJ** for fluent, readable assertions; avoid bare JUnit `assertEquals` chains.
- Use **Testcontainers** for integration tests that require real databases, message brokers, or external services.
- Test files must mirror the exact package path of the class under test.
- Name test methods descriptively: `should_<expectedBehavior>_when_<condition>` (e.g., `should_throwNotFoundException_when_userIdIsInvalid`).
- Aim for high branch coverage on core business logic; avoid fixating on line coverage alone.

### 5. Logging
- Use **SLF4J** as the logging facade; bind to **Logback** (default in Spring Boot) or **Log4j2** as the concrete backend.
- Log meaningful context (entity IDs, correlation IDs, operation names) rather than generic "success" / "failed" messages.
- Use parameterized log statements: `log.debug("Fetching user id={}", userId)` — never string concatenation.
- Apply `DEBUG`/`TRACE` at method entry/exit for complex logic; use `INFO` for significant state transitions; reserve `WARN`/`ERROR` for recoverable/unrecoverable failures respectively.
- Always include the stack trace when logging caught exceptions: `log.error("Operation failed for id={}", id, e)`.

### 6. Code Style & Formatting
- Use **Spotless** (Maven/Gradle plugin) with **Google Java Format** or **Palantir Java Format** as the automated formatter — run it as part of the build (`spotless:apply`). This is the Java equivalent of Ruff/Black; let tooling enforce style, not manual review.
- Adhere to any `checkstyle.xml` present in the project for structural rules (import ordering, Javadoc presence, etc.).
- **Never** use fully qualified class names inline — always import:
  - ❌ `java.util.List<String> list = new java.util.ArrayList<>();`
  - ✅ `List<String> list = new ArrayList<>();`
- Organize imports in ascending alphabetical order; place all static imports at the end of the import block.
- Prefer `List.of()`, `Map.of()`, `Set.of()` over mutable collection constructors unless mutability is explicitly needed.
- **Never** write long, single-line method chains. Use tree-based formatting (one method call per line) to improve readability and ensure the code fits within standard screen widths without horizontal scrolling.

### 7. Null Safety & Optional
- Return `Optional<T>` from repository/service methods that may legitimately produce no result; never return `null` from public APIs.
- Avoid `Optional` as a field type or method parameter — use it only as a return type.
- Annotate method parameters and return types with `@NonNull` / `@Nullable` (from `org.springframework.lang` or `jakarta.annotation`) to make nullability intent explicit.

### 8. Error Handling
- Create a domain-specific exception hierarchy:
  - A base unchecked exception (e.g., `AppException extends RuntimeException`) with sub-types per domain concern (e.g., `NotFoundException`, `ValidationException`, `ConflictException`).
- Catch specific exceptions; never silently swallow them.
- Translate infrastructure exceptions (e.g., `DataAccessException`) at the boundary layer; do not let them leak into the domain or API layer.

### 9. Vulnerability & Dependency Management
- Regularly scan dependencies for known CVEs:
  - **OWASP Dependency-Check** (`mvn dependency-check:check` or `./gradlew dependencyCheckAnalyze`) — add to CI pipeline.
  - `./mvnw versions:display-dependency-updates` to surface outdated dependencies.
- Use **BOM (Bill of Materials)** imports (e.g., `spring-boot-dependencies`, `jackson-bom`) to align transitive dependency versions and reduce version-conflict risk.
- Pin dependency versions explicitly in production; avoid open ranges (`[1.0,)`) in `pom.xml` or `build.gradle`.
- Apply **SpotBugs** or **ErrorProne** for static analysis beyond style — they catch real bugs (null dereferences, resource leaks, incorrect `equals`/`hashCode`).