# GeoWake Architecture - Visual Diagrams (Mermaid)

This document contains visual architecture diagrams using Mermaid syntax that can be rendered directly in GitHub, IDEs, and documentation viewers.

---

## 1. High-Level System Architecture

```mermaid
graph TB
    subgraph "Presentation Layer"
        UI[Flutter UI]
        Screens[Screens]
        Widgets[Widgets]
    end
    
    subgraph "Service Layer"
        TrackingService[TrackingService<br/>Background GPS & Alarms]
        AlarmOrch[AlarmOrchestrator<br/>Alarm Logic]
        RouteServices[Route Services<br/>DirectionService, RouteCache]
        ETAServices[ETA & Position<br/>ETAEngine, SnapToRoute]
        NotifServices[Notification Services<br/>AlarmPlayer, NotificationService]
    end
    
    subgraph "Infrastructure Layer"
        API[APIClient<br/>Backend Proxy]
        Storage[Storage<br/>Hive, SecureStorage]
        Platform[Platform Services<br/>GPS, Battery, Sensors]
        Events[EventBus<br/>Pub/Sub]
    end
    
    UI --> TrackingService
    UI --> RouteServices
    Screens --> NotifServices
    
    TrackingService --> AlarmOrch
    TrackingService --> ETAServices
    TrackingService --> RouteServices
    
    AlarmOrch --> NotifServices
    RouteServices --> API
    ETAServices --> Platform
    
    TrackingService --> Events
    AlarmOrch --> Events
    RouteServices --> Storage
    
    style TrackingService fill:#ff9999
    style AlarmOrch fill:#ffcc99
    style API fill:#99ccff
    style Storage fill:#99ff99
```

---

## 2. Journey Start Flow

```mermaid
sequenceDiagram
    participant User
    participant HomeScreen
    participant PlacesService
    participant DirectionService
    participant RouteCache
    participant TrackingService
    participant MapTracking
    
    User->>HomeScreen: Select destination
    HomeScreen->>PlacesService: Search/Autocomplete
    PlacesService-->>HomeScreen: Place suggestions
    
    User->>HomeScreen: Set alarm parameters
    User->>HomeScreen: Start Journey
    
    HomeScreen->>DirectionService: getDirections()
    DirectionService->>RouteCache: Check cache
    
    alt Cache Hit
        RouteCache-->>DirectionService: Cached route
    else Cache Miss
        DirectionService->>API: Fetch from Google
        API-->>DirectionService: Route data
        DirectionService->>RouteCache: Store route
    end
    
    DirectionService-->>HomeScreen: Route ready
    HomeScreen->>RouteRegistry: Save route
    HomeScreen->>TrackingService: startTracking()
    
    TrackingService->>Background: Start isolate
    TrackingService->>GPS: Begin monitoring
    
    HomeScreen->>MapTracking: Navigate to tracking screen
    MapTracking->>TrackingService: Subscribe to updates
    
    Note over TrackingService,MapTracking: Continuous updates begin
```

---

## 3. Background Tracking & Alarm Decision Flow

```mermaid
flowchart TD
    Start[GPS Position Update] --> Validate[SampleValidator<br/>Accuracy & Bounds Check]
    Validate --> |Valid| Snap[SnapToRoute<br/>Project to route]
    Validate --> |Invalid| Reject[Reject Sample]
    
    Snap --> UpdateRoute[ActiveRouteManager<br/>Calculate progress]
    UpdateRoute --> CalcETA[ETAEngine<br/>Calculate ETA]
    
    CalcETA --> CheckDev[DeviationMonitor<br/>Check if on route]
    
    CheckDev --> |Deviated| Reroute[ReroutePolicy<br/>Cooldown check]
    Reroute --> |Should Reroute| FetchNew[Fetch new route]
    Reroute --> |Cooldown Active| Continue
    
    CheckDev --> |On Route| Evaluate[Evaluate Alarm Conditions]
    
    Evaluate --> Mode{Alarm Mode?}
    
    Mode --> |Distance| DistCheck[Distance <= Threshold?]
    Mode --> |Time| TimeCheck[ETA <= Threshold?]
    Mode --> |Stops| StopsCheck[Stops <= Threshold?]
    
    DistCheck --> |Yes| Dedup
    DistCheck --> |No| Continue[Continue Monitoring]
    
    TimeCheck --> |Yes| Dedup
    TimeCheck --> |No| Continue
    
    StopsCheck --> |Yes| Dedup
    StopsCheck --> |No| Continue
    
    Dedup[AlarmDeduplicator<br/>Check duplicate] --> |Not Duplicate| Fire[Fire Alarm!]
    Dedup --> |Duplicate| Continue
    
    Fire --> Phase1[Phase 1: Notification]
    Phase1 --> Phase2[Phase 2: Audio/Vibrate]
    Phase2 --> Phase3[Phase 3: Persist State]
    Phase3 --> Emit[Emit AlarmFired Event]
    
    Continue --> Wait[Wait for next GPS update]
    Wait --> Start
    
    style Fire fill:#ff6666
    style Phase1 fill:#ffaa66
    style Phase2 fill:#ffaa66
    style Phase3 fill:#ffaa66
```

---

## 4. Service Architecture Details

```mermaid
graph LR
    subgraph "Core Tracking"
        TS[TrackingService]
        ARM[ActiveRouteManager]
        DM[DeviationMonitor]
    end
    
    subgraph "Alarm System"
        AO[AlarmOrchestrator]
        AD[AlarmDeduplicator]
        PAS[PendingAlarmStore]
        AS[AlarmScheduler]
    end
    
    subgraph "Route Management"
        DS[DirectionService]
        RC[RouteCache]
        RR[RouteRegistry]
        OC[OfflineCoordinator]
    end
    
    subgraph "ETA & Position"
        EE[ETAEngine]
        STR[SnapToRoute]
        SF[SensorFusion]
        HS[HeadingSmoother]
    end
    
    subgraph "Notifications"
        NS[NotificationService]
        AP[AlarmPlayer]
        MSS[MetroStopService]
    end
    
    subgraph "Infrastructure"
        API[APIClient]
        SH[SecureHiveInit]
        EB[EventBus]
        PM[PersistenceManager]
    end
    
    TS --> ARM
    TS --> DM
    TS --> AO
    TS --> EE
    TS --> DS
    
    AO --> AD
    AO --> PAS
    AO --> AS
    AO --> NS
    AO --> AP
    
    DS --> RC
    DS --> OC
    DS --> API
    
    ARM --> STR
    ARM --> RR
    
    EE --> SF
    EE --> HS
    
    RC --> SH
    PAS --> SH
    RR --> SH
    
    TS --> EB
    AO --> EB
    DM --> EB
    
    TS --> PM
    
    style TS fill:#ff9999
    style AO fill:#ffcc99
    style DS fill:#99ccff
    style API fill:#6699ff
```

---

## 5. Data Flow Architecture

```mermaid
flowchart LR
    subgraph "Input Sources"
        GPS[GPS Sensor]
        ACC[Accelerometer]
        BAT[Battery]
        NET[Network]
    end
    
    subgraph "Processing Pipeline"
        VAL[Validation]
        FUSE[Sensor Fusion]
        SNAP[Route Snapping]
        ETA[ETA Calculation]
        ALARM[Alarm Evaluation]
    end
    
    subgraph "State Management"
        MEM[In-Memory State]
        CACHE[Route Cache]
        PERSIST[Persistence]
    end
    
    subgraph "Outputs"
        UI[UI Updates]
        NOTIF[Notifications]
        AUDIO[Audio/Vibrate]
        LOG[Logging/Metrics]
    end
    
    GPS --> VAL
    ACC --> FUSE
    BAT --> VAL
    
    VAL --> FUSE
    FUSE --> SNAP
    SNAP --> ETA
    ETA --> ALARM
    
    NET --> CACHE
    CACHE --> MEM
    MEM --> PERSIST
    
    ALARM --> NOTIF
    ALARM --> AUDIO
    ALARM --> UI
    
    ETA --> UI
    SNAP --> UI
    
    VAL --> LOG
    ALARM --> LOG
    
    style ALARM fill:#ff6666
    style NOTIF fill:#ffaa66
    style AUDIO fill:#ffaa66
```

---

## 6. State Persistence & Recovery

```mermaid
stateDiagram-v2
    [*] --> AppStart
    
    AppStart --> CheckState: Bootstrap
    
    CheckState --> NoState: No persisted state
    CheckState --> HasState: State found
    
    NoState --> HomeScreen: Normal flow
    HomeScreen --> CreateJourney: User creates route
    CreateJourney --> Tracking: Start tracking
    
    HasState --> LoadState: Load session
    LoadState --> CheckAlarm: Check pending alarm
    
    CheckAlarm --> FireAlarm: Alarm was due
    CheckAlarm --> ResumeTracking: No alarm
    
    FireAlarm --> Tracking
    ResumeTracking --> Tracking: Auto-resume
    
    Tracking --> Monitor: GPS updates
    Monitor --> Evaluate: Check conditions
    
    Evaluate --> SaveState: Periodic save (30s)
    SaveState --> Monitor
    
    Evaluate --> AlarmFired: Condition met
    AlarmFired --> Complete
    
    Monitor --> Crash: Process death
    Crash --> [*]
    
    Complete --> Stop: User stops
    Stop --> ClearState: Clean up
    ClearState --> [*]
    
    note right of SaveState
        Dual persistence:
        - File (app support dir)
        - SharedPreferences
    end note
    
    note right of HasState
        Recovery scenarios:
        - App crash
        - System kill
        - Battery death
        - Manual restart
    end note
```

---

## 7. Alarm Orchestrator State Machine

```mermaid
stateDiagram-v2
    [*] --> Idle: Initialize
    
    Idle --> Scheduled: Schedule fallback OS alarm
    Scheduled --> Monitoring: Begin monitoring
    
    Monitoring --> Evaluating: GPS update received
    
    Evaluating --> Monitoring: Conditions not met
    Evaluating --> Triggering: Alarm condition met
    
    Triggering --> Phase1: Show notification
    Phase1 --> Phase2: Play audio/vibrate
    Phase2 --> Phase3: Persist alarm state
    Phase3 --> Fired: Emit event
    
    Fired --> [*]: Alarm complete
    
    Monitoring --> Cancelled: User stops tracking
    Scheduled --> Cancelled: User stops
    Cancelled --> [*]
    
    note right of Triggering
        Race condition protection
        via synchronized lock
    end note
    
    note right of Phase3
        Dual persistence for
        crash recovery
    end note
```

---

## 8. Route Cache Strategy

```mermaid
flowchart TD
    Request[Route Request] --> Online{Online?}
    
    Online --> |No| CheckCache1[Check Cache]
    CheckCache1 --> |Hit| UseCache1[Use Cached Route]
    CheckCache1 --> |Miss| Error[Return Error]
    
    Online --> |Yes| CheckCache2[Check Cache First]
    CheckCache2 --> ValidateTTL{TTL Valid?<br/>< 5 min}
    
    ValidateTTL --> |No| FetchAPI
    ValidateTTL --> |Yes| CheckOrigin{Origin Deviation?<br/>< 50m}
    
    CheckOrigin --> |No| FetchAPI[Fetch from API]
    CheckOrigin --> |Yes| UseCache2[Use Cached Route<br/>80% hit rate!]
    
    FetchAPI --> Process[Process Response]
    Process --> Decode[Decode Polyline]
    Decode --> Simplify[Simplify<br/>Douglas-Peucker]
    Simplify --> Store[Store in Cache]
    Store --> Encrypt[Encrypt AES-256]
    Encrypt --> Return[Return Route]
    
    UseCache1 --> Return
    UseCache2 --> Return
    
    Return --> [*]
    Error --> [*]
    
    style UseCache2 fill:#99ff99
    style FetchAPI fill:#ffcc99
    style Error fill:#ff9999
```

---

## 9. Battery & Power Management

```mermaid
flowchart TD
    Start[Check Battery Level] --> Level{Battery Level}
    
    Level --> |> 60%| High[High Power Mode]
    Level --> |20-60%| Medium[Medium Power Mode]
    Level --> |< 20%| Low[Low Power Mode]
    
    High --> GPS5[GPS Interval: 5s<br/>Accuracy: High]
    Medium --> GPS10[GPS Interval: 10s<br/>Accuracy: Medium]
    Low --> GPS20[GPS Interval: 20s<br/>Accuracy: Medium]
    
    GPS5 --> CheckIdle
    GPS10 --> CheckIdle
    GPS20 --> CheckIdle
    
    CheckIdle{User Idle?} --> |Yes| Scale[Scale Interval Up<br/>IdlePowerScaler]
    CheckIdle --> |No| Apply[Apply Settings]
    
    Scale --> Apply
    Apply --> Monitor[Monitor for 60s]
    Monitor --> Start
    
    style High fill:#99ff99
    style Medium fill:#ffff99
    style Low fill:#ffcc99
```

---

## 10. Event Bus Communication

```mermaid
graph TB
    subgraph Publishers
        TS[TrackingService]
        AO[AlarmOrchestrator]
        DM[DeviationMonitor]
        RP[ReroutePolicy]
    end
    
    subgraph "EventBus (Pub/Sub)"
        EB[EventBus<br/>Central Hub]
    end
    
    subgraph Subscribers
        MT[MapTrackingScreen]
        DS[DiagnosticsScreen]
        NS[NotificationService]
        MR[MetricsRegistry]
    end
    
    TS -->|AlarmFiredEvent| EB
    TS -->|ActiveRouteState| EB
    TS -->|RouteSwitchEvent| EB
    
    AO -->|AlarmFiredPhase1Event| EB
    AO -->|AlarmFiredPhase2Event| EB
    AO -->|AlarmScheduledEvent| EB
    
    DM -->|DeviationDetectedEvent| EB
    RP -->|RerouteDecision| EB
    
    EB -->|Updates| MT
    EB -->|Metrics| MR
    EB -->|Alerts| NS
    EB -->|Debug Info| DS
    
    style EB fill:#ffcc99
```

---

## 11. Security Layers

```mermaid
flowchart TD
    subgraph "Application Layer"
        UI[User Interface]
        Services[Services]
    end
    
    subgraph "Security Layer 1: Network"
        Proxy[Backend API Proxy]
        SSL[SSL/TLS]
    end
    
    subgraph "Security Layer 2: Storage"
        AES[AES-256 Encryption]
        SecStore[Secure Key Storage]
    end
    
    subgraph "Security Layer 3: Validation"
        PosVal[Position Validation]
        InputVal[Input Validation]
    end
    
    subgraph "Security Layer 4: Access"
        Perms[Permission Checks]
        Auth[Authorization]
    end
    
    subgraph "External"
        API[Google Maps API]
        GPS[GPS Hardware]
        Storage[Device Storage]
    end
    
    UI --> Services
    Services --> Proxy
    Proxy --> SSL
    SSL --> API
    
    Services --> AES
    AES --> SecStore
    SecStore --> Storage
    
    GPS --> PosVal
    PosVal --> InputVal
    InputVal --> Services
    
    Services --> Perms
    Perms --> Auth
    Auth --> GPS
    
    style AES fill:#99ff99
    style SSL fill:#99ccff
    style PosVal fill:#ffcc99
    style Perms fill:#ff9999
```

---

## 12. Component Dependencies

```mermaid
graph TD
    Main[main.dart] --> Boot[BootstrapService]
    Main --> Theme[AppThemes]
    Main --> Nav[NavigationService]
    
    Boot --> API[APIClient]
    Boot --> Notif[NotificationService]
    Boot --> Track[TrackingService]
    
    Track --> Route[RouteRegistry]
    Track --> ARM[ActiveRouteManager]
    Track --> Alarm[AlarmOrchestrator]
    Track --> Dev[DeviationMonitor]
    
    Alarm --> NotifSvc[NotificationService]
    Alarm --> Player[AlarmPlayer]
    Alarm --> Store[PendingAlarmStore]
    
    Route --> Cache[RouteCache]
    Route --> Hive[SecureHiveInit]
    
    ARM --> Snap[SnapToRoute]
    ARM --> ETA[ETAEngine]
    
    Dev --> Reroute[ReroutePolicy]
    
    API --> Backend[Backend Server]
    Cache --> Hive
    Store --> Hive
    
    style Main fill:#ff9999
    style Track fill:#ffcc99
    style Alarm fill:#ffff99
    style Hive fill:#99ff99
```

---

**Note**: These Mermaid diagrams can be viewed directly in:
- GitHub (automatic rendering)
- VS Code (with Mermaid preview extension)
- IntelliJ/PyCharm (with Mermaid plugin)
- Any Markdown viewer with Mermaid support

To export as images:
- Use [Mermaid Live Editor](https://mermaid.live)
- Use CLI tools like `mmdc` (mermaid-cli)
- Use IDE export functions

---

**Document Version**: 1.0.0  
**Created**: October 24, 2025  
**Format**: Mermaid Diagrams
