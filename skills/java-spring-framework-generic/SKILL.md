---
name: java-spring-framework-generic
description: >
  Comprehensive guidelines, patterns, and best practices for Spring Boot 3.x
  application development — covering REST APIs, data access, security,
  observability, async patterns, testing, and production readiness.
version: 1.0.0
triggers:
  - "work on spring boot project"
  - "create spring boot application"
  - "spring rest api"
  - "spring data jpa"
  - "spring security"
  - "spring boot backend"
  - "spring framework"
intent: execution
guardrails:
  - "Target Spring Boot 3.x (Jakarta EE 10+) and Java 21 LTS unless the project is explicitly pinned to an older version."
  - "Always use constructor injection. Never use field injection (@Autowired on fields). Never use setter injection unless the dependency is optional."
  - "Never expose JPA entity objects directly from REST controllers. Use dedicated DTO/record classes for request and response payloads."
  - "Always annotate service-layer write operations with @Transactional. Never annotate controller methods directly."
  - "Do not use System.out.println. Use SLF4J (log.debug / log.info / log.warn / log.error) with parameterized messages."
  - "Never hardcode secrets, passwords, or API keys. Use application properties bound to @ConfigurationProperties beans, backed by environment variables or a secrets manager."
  - "Always validate incoming request payloads using Jakarta Bean Validation (@Valid / @Validated). Reject invalid input at the controller boundary — never in the service layer."
  - "When starting a new app, ALWAYS check if an OpenAPI schema is available. If yes, build the API around it. If starting from scratch, ALWAYS provide an OpenAPI schema for the APIs before implementation."
  - "Always use MockMvc for testing REST controllers."
  - "Check for SDKMAN environment variables (JAVA_HOME, JAVA21_HOME, SDKMAN_CANDIDATES_DIR) and use them when present."
  - "Always run builds via the project wrapper (./mvnw or ./gradlew), never with a globally installed tool."
tools:
  - bash
interface:
  input:
    task: "string — description of the Spring Boot task"
  output:
    status: "string — outcome of the operation"
---
## Spring Framework Development Guidelines

---

### 0. Version Baseline

- **Spring Boot 3.x** (minimum 3.2) with **Java 21 LTS** is the target baseline.
- Spring Boot 3.x requires **Jakarta EE 10** — all `javax.*` imports become `jakarta.*` (persistence, validation, servlet, etc.). Never mix the two.
- Use the **Spring Boot BOM** as the dependency version anchor; override individual versions only when a CVE or feature specifically requires it.
- Track the [Spring Boot support timeline](https://spring.io/projects/spring-boot#support); run on a supported OSS or commercial release only.

---

### 1. Project Bootstrap & Structure

#### Starting a Project
- Use [start.spring.io](https://start.spring.io) (or the IntelliJ / VS Code Spring Initializr plugin) for new projects. Do not assemble BOMs manually.
- **Contract First:** Always check if there is an existing OpenAPI schema available. If yes, build the API around it. If starting from scratch, always design and provide an OpenAPI schema for the APIs first.
- Select dependencies deliberately — avoid pulling in starters you won't use (they add auto-configuration and startup overhead).

#### Recommended Starter Set (web API)
```
spring-boot-starter-web          # MVC + embedded Tomcat (or swap to WebFlux)
spring-boot-starter-data-jpa     # Hibernate + Spring Data
spring-boot-starter-validation   # Jakarta Bean Validation
spring-boot-starter-security     # Spring Security
spring-boot-starter-actuator     # Health, metrics, info endpoints
spring-boot-starter-test         # JUnit 5, Mockito, AssertJ, MockMvc
springdoc-openapi-starter-webmvc-ui  # OpenAPI 3 + Swagger UI
```

#### Package Layout
```
src/
  main/
    java/com/example/app/
      Application.java              ← @SpringBootApplication (root package only)
      controller/                   ← @RestController, thin HTTP boundary
      service/                      ← @Service, business logic
      repository/                   ← @Repository, Spring Data interfaces
      domain/                       ← JPA @Entity classes, domain model
      dto/                          ← Request/Response records and classes
      config/                       ← @Configuration classes, Beans
      exception/                    ← Custom exception hierarchy
      security/                     ← Security config, filters, handlers
      event/                        ← Domain events and listeners
    resources/
      application.yml               ← Base config
      application-local.yml         ← Local dev overrides (gitignored)
      application-test.yml          ← Test overrides
  test/
    java/com/example/app/
      controller/                   ← @WebMvcTest slice tests
      service/                      ← Unit tests with Mockito
      repository/                   ← @DataJpaTest slice tests
      integration/                  ← @SpringBootTest + Testcontainers
```

- **`Application.java` must live in the root package** so component scanning covers all sub-packages without explicit `scanBasePackages`.
- Keep `config/` classes focused: one `@Configuration` per concern (security, cache, async, openapi, etc.). Never mix unrelated beans in a single config class.

---

### 2. Dependency Injection

#### Constructor Injection (Always)
```java
// ✅ Correct — Lombok @RequiredArgsConstructor generates the constructor
@Service
@RequiredArgsConstructor
public class OrderService {
    private final OrderRepository orderRepository;
    private final PaymentGateway paymentGateway;
    private final ApplicationEventPublisher eventPublisher;
}

// ❌ Never — field injection hides dependencies, breaks testability
@Service
public class OrderService {
    @Autowired private OrderRepository orderRepository;
}
```
- Mark injected fields `private final` — this enforces immutability and makes the dependency graph explicit.
- Use `@RequiredArgsConstructor` (Lombok) to eliminate boilerplate; only write the constructor manually when you need custom validation or logging inside it.

#### Bean Scoping
- Default to `@Scope("singleton")` (Spring's default) — never deviate without explicit justification.
- Use `@RequestScope` only for beans that truly carry per-request state (e.g., a security context holder wrapper).
- Avoid prototype-scoped beans injected into singletons without a `Provider<T>` or `ObjectFactory<T>` wrapper — it causes stale-proxy bugs.

---

### 3. Configuration Management

#### `application.yml` over `application.properties`
- Prefer YAML for hierarchy and readability; keep the base file for shared config and use profile-specific files for overrides.

#### Typed Configuration with `@ConfigurationProperties`
```java
// ✅ Bind a whole config namespace to a strongly-typed bean
@ConfigurationProperties(prefix = "app.payment")
@Validated
public record PaymentProperties(
    @NotBlank String gatewayUrl,
    @NotBlank String apiKey,
    @Min(1) @Max(30) int timeoutSeconds
) {}

// Register it
@SpringBootApplication
@EnableConfigurationProperties(PaymentProperties.class)
public class Application { ... }
```
- **Never** use `@Value("${some.property}")` for groups of related properties — it scatters config across the codebase.
- Use `@Value` only for single, isolated values injected into a `@Bean` method in a `@Configuration` class.
- Keep secrets out of YAML entirely. Reference environment variables:
  ```yaml
  app:
    payment:
      api-key: ${PAYMENT_API_KEY}   # resolved from env at runtime
  ```

#### Profiles
- Define environments with profiles: `local`, `dev`, `staging`, `prod`.
- Activate via `SPRING_PROFILES_ACTIVE` environment variable, not in checked-in YAML.
- Use `application-local.yml` (gitignored) for developer-specific overrides (local DB URLs, stubbed services).
- Never use `@Profile` on `@Service` or `@Repository` beans — it makes the business logic depend on infrastructure decisions. Use it only in `@Configuration` classes to swap implementations.

---

### 4. REST Controllers

#### Design Rules
- Controllers are **thin HTTP boundaries** only — no business logic, no repository calls.
- Use `@RestController` + `@RequestMapping` at the class level; map HTTP verbs with `@GetMapping`, `@PostMapping`, etc.
- Return `ResponseEntity<T>` only when you need to control the HTTP status or headers dynamically. For fixed-status endpoints, return the DTO directly and use `@ResponseStatus` on the method.

```java
@RestController
@RequestMapping("/api/v1/orders")
@RequiredArgsConstructor
@Tag(name = "Orders", description = "Order lifecycle management")
public class OrderController {

    private final OrderService orderService;

    @GetMapping("/{id}")
    @Operation(summary = "Fetch an order by ID")
    public OrderResponse getOrder(@PathVariable UUID id) {
        return orderService.findById(id);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public OrderResponse createOrder(@RequestBody @Valid CreateOrderRequest request) {
        return orderService.create(request);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void cancelOrder(@PathVariable UUID id) {
        orderService.cancel(id);
    }
}
```

#### DTOs as Records
```java
// Request DTO — validated at the controller boundary
public record CreateOrderRequest(
    @NotNull UUID customerId,
    @NotEmpty List<@Valid OrderLineItem> items,
    @NotBlank String shippingAddress
) {}

// Response DTO — never expose entity fields directly
public record OrderResponse(
    UUID id,
    String status,
    BigDecimal totalAmount,
    Instant createdAt
) {}
```
- Use Java records for DTOs — they are immutable, compact, and generate `equals`/`hashCode`/`toString` automatically.
- Use a dedicated mapper (MapStruct recommended) to convert between entities and DTOs. Never do it inline in controllers or services.

#### API Versioning
- Version via URL path (`/api/v1/...`) for simplicity; use headers only when clients cannot change URLs.
- Never version by removing old endpoints — deprecate with `@Deprecated` + a `Deprecation` header, then remove after a defined sunset period.

---

### 5. Service Layer

- Every public method that writes state must be annotated `@Transactional`.
- Read-only methods should use `@Transactional(readOnly = true)` — Hibernate uses this to skip dirty-checking and flush, which improves read performance.
- **Never call a `@Transactional` method from within the same bean** (self-invocation bypasses the proxy and the transaction boundary). Extract to a separate bean if needed.
- Services must not import `jakarta.servlet.*` or any HTTP-layer type — they must remain transport-agnostic.

```java
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)   // default to read-only; override on writes
public class OrderService {

    private final OrderRepository orderRepository;
    private final OrderMapper orderMapper;
    private final ApplicationEventPublisher eventPublisher;

    public OrderResponse findById(UUID id) {
        return orderRepository.findById(id)
            .map(orderMapper::toResponse)
            .orElseThrow(() -> new NotFoundException("Order not found: " + id));
    }

    @Transactional
    public OrderResponse create(CreateOrderRequest request) {
        Order order = orderMapper.toEntity(request);
        Order saved = orderRepository.save(order);
        eventPublisher.publishEvent(new OrderCreatedEvent(saved.getId()));
        return orderMapper.toResponse(saved);
    }
}
```

---

### 6. Data Access — Spring Data JPA

#### Entity Design
```java
@Entity
@Table(name = "orders")
@Getter                          // Lombok — only getters; entities should not be fully mutable
@NoArgsConstructor(access = AccessLevel.PROTECTED)  // required by JPA
public class Order {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)  // Java UUID, no sequence contention
    private UUID id;

    @Column(nullable = false)
    private UUID customerId;

    @Enumerated(EnumType.STRING)  // always STRING, never ORDINAL
    @Column(nullable = false)
    private OrderStatus status;

    @CreationTimestamp
    private Instant createdAt;

    @UpdateTimestamp
    private Instant updatedAt;

    @Version                      // optimistic locking — always include on mutable entities
    private Long version;

    // Factory method instead of public constructor
    public static Order create(UUID customerId) {
        Order o = new Order();
        o.customerId = customerId;
        o.status = OrderStatus.PENDING;
        return o;
    }
}
```

#### Repository Patterns
```java
public interface OrderRepository extends JpaRepository<Order, UUID> {

    // Derived query — fine for simple predicates
    List<Order> findByCustomerIdAndStatus(UUID customerId, OrderStatus status);

    // JPQL for complex queries — prefer over native SQL for portability
    @Query("SELECT o FROM Order o WHERE o.createdAt >= :since AND o.status = :status")
    Page<Order> findRecentByStatus(@Param("since") Instant since,
                                   @Param("status") OrderStatus status,
                                   Pageable pageable);

    // Projection — avoid SELECT * when only a subset of fields is needed
    @Query("SELECT o.id as id, o.status as status FROM Order o WHERE o.customerId = :id")
    List<OrderSummary> findSummariesByCustomerId(@Param("id") UUID customerId);
}
```

#### JPA Rules
- **Always use `EnumType.STRING`** — `ORDINAL` breaks if the enum order ever changes.
- **Always add `@Version`** on entities with concurrent writes for optimistic locking.
- **Avoid `FetchType.EAGER`** — it generates N+1 queries. Use `FetchType.LAZY` everywhere and load associations explicitly with `JOIN FETCH` in JPQL when needed.
- **Use Projections** (interfaces or records) for read-heavy queries to avoid hydrating full entity objects.
- **Never call `flush()` or `clear()` manually** outside of batch-processing loops — it defeats JPA's unit-of-work semantics.
- Use **Flyway** or **Liquibase** for schema migrations. Never rely on `spring.jpa.hibernate.ddl-auto=update` in any environment above `local`.

---

### 7. Exception Handling

#### Exception Hierarchy
```java
// Base application exception
public abstract class AppException extends RuntimeException {
    private final HttpStatus status;

    protected AppException(String message, HttpStatus status) {
        super(message);
        this.status = status;
    }

    protected AppException(String message, HttpStatus status, Throwable cause) {
        super(message, cause);
        this.status = status;
    }

    public HttpStatus getStatus() { return status; }
}

// Concrete domain exceptions
public class NotFoundException    extends AppException { public NotFoundException(String m)    { super(m, HttpStatus.NOT_FOUND); } }
public class ConflictException    extends AppException { public ConflictException(String m)    { super(m, HttpStatus.CONFLICT); } }
public class ValidationException  extends AppException { public ValidationException(String m)  { super(m, HttpStatus.BAD_REQUEST); } }
public class ForbiddenException   extends AppException { public ForbiddenException(String m)   { super(m, HttpStatus.FORBIDDEN); } }
```

#### Global Handler with `@RestControllerAdvice`
```java
@RestControllerAdvice
@Slf4j
public class GlobalExceptionHandler {

    @ExceptionHandler(AppException.class)
    public ResponseEntity<ErrorResponse> handleAppException(AppException ex, HttpServletRequest request) {
        log.warn("Application error at {}: {}", request.getRequestURI(), ex.getMessage());
        return ResponseEntity.status(ex.getStatus())
            .body(new ErrorResponse(ex.getStatus().value(), ex.getMessage(), request.getRequestURI()));
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ErrorResponse> handleValidation(MethodArgumentNotValidException ex, HttpServletRequest request) {
        String detail = ex.getBindingResult().getFieldErrors().stream()
            .map(fe -> fe.getField() + ": " + fe.getDefaultMessage())
            .collect(Collectors.joining("; "));
        return ResponseEntity.badRequest()
            .body(new ErrorResponse(400, "Validation failed: " + detail, request.getRequestURI()));
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ErrorResponse> handleUnexpected(Exception ex, HttpServletRequest request) {
        log.error("Unexpected error at {}", request.getRequestURI(), ex);   // ← always include ex for stack trace
        return ResponseEntity.internalServerError()
            .body(new ErrorResponse(500, "Internal server error", request.getRequestURI()));
    }
}

public record ErrorResponse(int status, String message, String path) {}
```
- **Never leak stack traces, internal class names, or raw exception messages** to API consumers.
- Log unexpected exceptions at `ERROR` level with the full throwable; log expected/business exceptions at `WARN`.

---

### 8. Validation

- Annotate all `@RequestBody` parameters with `@Valid` to trigger Jakarta Bean Validation.
- For service-level method parameter validation, add `@Validated` to the class and `@Valid` to the method parameter.
- Use standard annotations: `@NotNull`, `@NotBlank`, `@NotEmpty`, `@Size`, `@Min`, `@Max`, `@Email`, `@Pattern`.
- For complex cross-field rules, implement a custom `ConstraintValidator<A, T>`:

```java
@Documented
@Constraint(validatedBy = DateRangeValidator.class)
@Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)
public @interface ValidDateRange {
    String message() default "End date must be after start date";
    Class<?>[] groups() default {};
    Class<? extends Payload>[] payload() default {};
}
```
- Never duplicate validation logic between the controller and service layers. Validate once at the entry boundary.

---

### 9. Spring Security

#### Configuration (Lambda DSL — Spring Security 6+)
```java
@Configuration
@EnableWebSecurity
@EnableMethodSecurity          // enables @PreAuthorize, @PostAuthorize
@RequiredArgsConstructor
public class SecurityConfig {

    private final JwtAuthenticationFilter jwtFilter;

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        return http
            .csrf(AbstractHttpConfigurer::disable)          // stateless API — CSRF not applicable
            .sessionManagement(sm -> sm.sessionCreationPolicy(STATELESS))
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/api/v1/auth/**", "/actuator/health/**", "/v3/api-docs/**", "/swagger-ui/**").permitAll()
                .anyRequest().authenticated()
            )
            .addFilterBefore(jwtFilter, UsernamePasswordAuthenticationFilter.class)
            .exceptionHandling(ex -> ex
                .authenticationEntryPoint(new HttpStatusEntryPoint(HttpStatus.UNAUTHORIZED))
                .accessDeniedHandler((req, res, e) -> res.sendError(HttpServletResponse.SC_FORBIDDEN))
            )
            .build();
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder(12);  // cost factor 12 — balance of security and latency
    }
}
```

#### Method-Level Authorization
```java
@Service
public class DocumentService {

    @PreAuthorize("hasRole('ADMIN') or @documentSecurity.isOwner(#id, authentication)")
    public Document findById(UUID id) { ... }

    @PreAuthorize("hasAuthority('document:write')")
    public Document update(UUID id, UpdateRequest req) { ... }
}
```

#### Security Rules
- **Never store passwords in plain text** — always encode with `BCryptPasswordEncoder` (min cost 10).
- **Use authority-based access control** (`hasAuthority('resource:action')`) over role-based (`hasRole('ADMIN')`) for fine-grained permissions.
- **Validate and sanitize JWTs** — check signature, issuer, audience, and expiry. Use `spring-security-oauth2-resource-server` for JWT validation rather than rolling your own filter.
- **Rate-limit authentication endpoints** to mitigate brute-force attacks.
- **Never log tokens, passwords, or PII** — scrub sensitive fields in log appenders if necessary.

---

### 10. Testing Strategy

#### Test Pyramid
```
                      ┌────────────────────────┐
                      │   @SpringBootTest       │  ← Integration / E2E (few, slow)
                      │   + Testcontainers      │
                  ┌───┴────────────────────────┴───┐
                  │  @WebMvcTest   @DataJpaTest     │  ← Slice tests (medium)
              ┌───┴─────────────────────────────────┴───┐
              │        Plain JUnit 5 + Mockito           │  ← Unit tests (many, fast)
              └─────────────────────────────────────────┘
```

#### Unit Tests (Service Layer)
```java
@ExtendWith(MockitoExtension.class)
class OrderServiceTest {

    @Mock OrderRepository orderRepository;
    @Mock OrderMapper orderMapper;
    @Mock ApplicationEventPublisher eventPublisher;

    @InjectMocks OrderService orderService;

    @Test
    void should_throwNotFoundException_when_orderIdDoesNotExist() {
        given(orderRepository.findById(any())).willReturn(Optional.empty());
        assertThatThrownBy(() -> orderService.findById(UUID.randomUUID()))
            .isInstanceOf(NotFoundException.class);
    }
}
```

#### Slice Tests — Controller (`@WebMvcTest`)
- **Always use MockMvc** for testing REST controllers to verify HTTP mappings, validation, and JSON serialization.

```java
@WebMvcTest(OrderController.class)
class OrderControllerTest {

    @Autowired MockMvc mockMvc;
    @MockBean OrderService orderService;
    @Autowired ObjectMapper objectMapper;

    @Test
    void should_return404_when_orderNotFound() throws Exception {
        given(orderService.findById(any())).willThrow(new NotFoundException("Order not found"));
        mockMvc.perform(get("/api/v1/orders/{id}", UUID.randomUUID()))
            .andExpect(status().isNotFound())
            .andExpect(jsonPath("$.status").value(404));
    }
}
```

#### Slice Tests — Repository (`@DataJpaTest`)
```java
@DataJpaTest
@AutoConfigureTestDatabase(replace = NONE)   // use real DB via Testcontainers
@Import(TestcontainersConfig.class)
class OrderRepositoryTest {

    @Autowired OrderRepository orderRepository;

    @Test
    void should_findOrdersByCustomerAndStatus() {
        // persist test data, then assert
    }
}
```

#### Integration Tests (`@SpringBootTest` + Testcontainers)
```java
@SpringBootTest(webEnvironment = RANDOM_PORT)
@Testcontainers
class OrderIntegrationTest {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16-alpine");

    @DynamicPropertySource
    static void configureDb(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
    }

    @Autowired TestRestTemplate restTemplate;

    @Test
    void should_createAndFetchOrder_end_to_end() { ... }
}
```

#### Test Rules
- Use `@MockBean` only in `@WebMvcTest` / `@SpringBootTest` — it reloads the context; use `@Mock` in plain unit tests.
- Use **AssertJ** (`assertThat`, `assertThatThrownBy`) — never JUnit's raw `assertEquals`.
- Use **`@Sql`** or **`@BeforeEach` fixtures** for repository tests; never rely on data left by other tests.
- Name all tests: `should_<result>_when_<condition>`.

---

### 11. Observability

#### Spring Boot Actuator
```yaml
management:
  endpoints:
    web:
      exposure:
        include: health, info, metrics, prometheus
  endpoint:
    health:
      show-details: when-authorized
      probes:
        enabled: true          # enables /health/liveness and /health/readiness for K8s
  metrics:
    tags:
      application: ${spring.application.name}
```
- **Never expose all actuator endpoints publicly** — secure them behind a role or restrict to an internal management port.
- Use `/health/liveness` and `/health/readiness` as Kubernetes probe targets.

#### Micrometer Metrics
```java
@Service
@RequiredArgsConstructor
public class OrderService {

    private final MeterRegistry registry;

    @Counted(value = "orders.created", description = "Total orders created")
    @Timed(value = "orders.create.duration", description = "Time to create an order")
    @Transactional
    public OrderResponse create(CreateOrderRequest request) { ... }
}
```
- Tag metrics with `application`, `environment`, and relevant business dimensions (e.g., `order.type`).
- Export to **Prometheus** via `micrometer-registry-prometheus`; visualize with Grafana.

#### Distributed Tracing
- Use **Micrometer Tracing** with the OpenTelemetry bridge (`micrometer-tracing-bridge-otel`) — the replacement for Spring Cloud Sleuth in Spring Boot 3.x.
- Propagate `traceId` and `spanId` in log output via MDC (Logback auto-configures this when `micrometer-tracing` is on the classpath).
- Include `traceId` in API error responses to correlate user-reported errors with logs.

---

### 12. Async & Concurrency

#### Virtual Threads (Java 21 + Spring Boot 3.2+)
```yaml
# Enable virtual threads for embedded Tomcat — replaces the platform thread pool
spring:
  threads:
    virtual:
      enabled: true
```
- With virtual threads enabled, you can use blocking I/O in `@Async` methods and request handlers without thread-pool starvation — the JVM handles the scheduling.
- **Do not use `synchronized` blocks with virtual threads** — use `ReentrantLock` or `java.util.concurrent` primitives instead (synchronized pins carrier threads).

#### `@Async` for Fire-and-Forget
```java
@Configuration
@EnableAsync
public class AsyncConfig {

    @Bean(name = "taskExecutor")
    public Executor taskExecutor() {
        // With virtual threads enabled, this delegates to virtual thread factory
        return Executors.newVirtualThreadPerTaskExecutor();
    }
}

@Service
public class NotificationService {

    @Async("taskExecutor")
    public CompletableFuture<Void> sendWelcomeEmail(String email) {
        // I/O-bound work — perfect for virtual threads
        return CompletableFuture.completedFuture(null);
    }
}
```
- Always return `CompletableFuture<T>` from `@Async` methods — it allows callers to await completion and handle exceptions.
- Configure a custom executor with a meaningful name, rejection policy, and queue capacity.

---

### 13. Domain Events

- Use **`ApplicationEventPublisher`** to decouple domain side-effects (sending emails, updating read models, triggering workflows) from the core write transaction.
- Use `@TransactionalEventListener(phase = AFTER_COMMIT)` for listeners that must run only after the DB transaction commits successfully:

```java
// Publishing (in service)
eventPublisher.publishEvent(new OrderShippedEvent(order.getId(), order.getCustomerId()));

// Listening (in a separate bean)
@Component
@Slf4j
@RequiredArgsConstructor
public class OrderNotificationListener {

    private final NotificationService notificationService;

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    @Async
    public void onOrderShipped(OrderShippedEvent event) {
        notificationService.sendShippingConfirmation(event.customerId());
    }
}
```
- Keep event payloads as **immutable records** containing only IDs and essential data — never full entities.
- For cross-service event propagation, prefer a message broker (Kafka, RabbitMQ via Spring Cloud Stream) over in-process events.

---

### 14. Caching

```java
@Configuration
@EnableCaching
public class CacheConfig {

    @Bean
    public CacheManager cacheManager() {
        // Use Caffeine for in-process; swap to Redis for distributed
        CaffeineCacheManager manager = new CaffeineCacheManager();
        manager.setCaffeine(Caffeine.newBuilder().expireAfterWrite(10, TimeUnit.MINUTES).maximumSize(500));
        return manager;
    }
}

@Service
public class ProductService {

    @Cacheable(value = "products", key = "#id", unless = "#result == null")
    public ProductResponse findById(UUID id) { ... }

    @CacheEvict(value = "products", key = "#id")
    @Transactional
    public ProductResponse update(UUID id, UpdateProductRequest req) { ... }

    @CacheEvict(value = "products", allEntries = true)
    @Scheduled(cron = "0 0 * * * *")   // full eviction hourly as a safety net
    public void evictAllProducts() {}
}
```
- **Never cache mutable state that must be immediately consistent** — only cache reference data, read-heavy aggregates, or expensive computations.
- Always set a TTL and maximum size; unbounded caches are memory leaks.
- Use **Redis** (via `spring-boot-starter-data-redis`) for distributed / multi-instance deployments.

---

### 15. OpenAPI Documentation

```java
@Configuration
public class OpenApiConfig {

    @Bean
    public OpenAPI applicationOpenAPI() {
        return new OpenAPI()
            .info(new Info()
                .title("Order Service API")
                .version("v1")
                .description("Manages the full order lifecycle")
                .contact(new Contact().name("Platform Engineering").email("platform@example.com")))
            .addSecurityItem(new SecurityRequirement().addList("bearerAuth"))
            .components(new Components()
                .addSecuritySchemes("bearerAuth", new SecurityScheme()
                    .type(SecurityScheme.Type.HTTP).scheme("bearer").bearerFormat("JWT")));
    }
}
```
- Annotate controllers with `@Tag`, endpoints with `@Operation`, and response types with `@ApiResponse`.
- Keep Swagger UI disabled in production (`springdoc.swagger-ui.enabled=false` in the `prod` profile).
- Export the OpenAPI spec as a static file (`/v3/api-docs`) and version it alongside the codebase.

---

### 16. Production Readiness Checklist

```
□ Health probes configured (/health/liveness, /health/readiness)
□ Graceful shutdown enabled (server.shutdown=graceful)
□ Actuator secured — not exposed on public port
□ All secrets in environment variables or secrets manager (not in YAML)
□ Flyway / Liquibase migrations enabled; ddl-auto=validate or none
□ Connection pool sized (HikariCP: pool-size tuned per instance count)
□ Virtual threads enabled (spring.threads.virtual.enabled=true)
□ Distributed tracing configured (Micrometer Tracing + OTEL exporter)
□ Prometheus metrics endpoint exposed
□ Log format structured JSON (Logstash encoder or ECS layout for ELK)
□ OWASP Dependency-Check in CI pipeline
□ SpotBugs / ErrorProne in build
□ Testcontainers integration tests running in CI
□ Docker image built with layered JARs (spring-boot:build-image or Jib)
□ JVM flags set for container: -XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0
```