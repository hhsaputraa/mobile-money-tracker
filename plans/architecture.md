# System Architecture & Layering Design

## 1. Architectural Layers

```
lib/
├── core/                  # Cross-cutting concerns & shared infrastructure
│   ├── constants/         # App constants, route names, asset paths
│   ├── network/           # HTTP/REST Client & interceptors
│   ├── security/          # Encryption, hashing, token handlers
│   └── theme/             # Design tokens, colors, typography, themes
│
├── auth/                  # Feature: Authentication
│   ├── models/            # UserModel, AuthResult, AuthTokens
│   ├── presentation/      # LoginScreen, RegisterScreen, widgets
│   └── services/          # AuthService, TokenStorageService
│
└── main.dart              # Entrypoint & root MaterialApp
```

## 2. Layer Contracts & Dependency Rules

1. **Presentation depends on Services & Models** (Downwards only).
2. **Services depend on Core Network & Security**.
3. **Core is independent** of all feature modules.
4. **Models are pure Dart data classes** with zero UI or framework dependencies.
