# HKNetworkKit

A production-ready, reusable Swift networking framework built on `URLSession` with
**zero third-party dependencies**. Designed around protocol-oriented programming,
dependency injection, and modern Swift concurrency (`async/await`).

## Features

- URLSession-based, async/await first
- Declarative `Endpoint` protocol (base URL, path, method, headers, query, body, timeout, cache policy, auth)
- Generic, `Codable` request/response handling with custom encoder/decoder config
- Multipart/form-data, file & image upload, download — all with **progress callbacks**
- Pluggable **authentication** (Bearer, Basic, API key) with automatic **token refresh + retry** on 401
- **Interceptors** (adapt requests, sign, inject headers, inspect responses)
- **Middleware** for logging, analytics, and metrics
- Configurable **retry policy** (fixed / exponential backoff, status-code & network-error rules)
- Comprehensive `APIError` taxonomy
- **SSL / public-key pinning** and HTTPS enforcement
- Built-in **network reachability** monitor (`NWPathMonitor`-based, no dependencies) with optional fail-fast-when-offline
- Optional **image loading** (`HKNetworkKitImage`): memory + disk cache, request de-duplication, UIKit & SwiftUI helpers — an in-house, dependency-free alternative to SDWebImage
- Fully mockable (`URLSessionProtocol` + `MockURLSession`) for unit testing

## Installation

Three products ship from this one package — add only what you need:
`HKNetworkKit` (core), `HKNetworkKitImage` (image loading), `KeyboardKit` (iOS keyboard).

### Swift Package Manager (recommended)

In Xcode: **File ▸ Add Package Dependencies…**, paste the repo URL, pick a version,
then add the products you want. Or in a `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/<your-username>/HKNetworkKit.git", from: "1.0.0")
],
targets: [
    .target(name: "MyApp", dependencies: [
        .product(name: "HKNetworkKit",      package: "HKNetworkKit"),
        .product(name: "HKNetworkKitImage", package: "HKNetworkKit"),  // optional
        .product(name: "KeyboardKit",     package: "HKNetworkKit"),  // optional
    ])
]
```

### CocoaPods

```ruby
pod 'HKNetworkKit'                 # core only (default subspec)
pod 'HKNetworkKit/Image'           # + image loading
pod 'HKNetworkKit/Keyboard'        # + keyboard handling
```

> CocoaPods compiles all subspecs into a **single module**, so Pod users write
> `import HKNetworkKit` for everything (SPM users keep the separate
> `import HKNetworkKitImage` / `import KeyboardKit`).

---

### Publishing it (free, for everyone)

**Step 1 — push to a public GitHub repo with a version tag.** SPM resolves
versions from git tags; this alone makes SPM installs work — no registration, no fees.

```bash
cd framework_api_service
git init && git add . && git commit -m "HKNetworkKit 1.0.0"
git branch -M main
git remote add origin https://github.com/<your-username>/HKNetworkKit.git
git push -u origin main
git tag 1.0.0 && git push origin 1.0.0          # tag = the SPM/Pod version
```

That's everything SPM needs. Share the URL — anyone can add it for free.

**Step 2 (optional) — publish to CocoaPods trunk** so `pod install` works:

```bash
# a) Pick a UNIQUE pod name (edit HKNetworkKit.podspec — "HKNetworkKit" is likely taken),
#    and set the homepage/source URLs to your repo.

# b) Validate the spec against the pushed tag:
pod spec lint HKNetworkKit.podspec        # use `pod lib lint` to check locally first

# c) One-time: register your email with trunk (creates a free account):
pod trunk register support@nuverse.in 'Harsh Kadiya' --description='mac'
#    (click the link in the confirmation email)

# d) Publish:
pod trunk push HKNetworkKit.podspec
```

After that, `pod 'HKNetworkKit'` resolves for everyone. New releases = bump
`s.version`, push a matching git tag, run `pod trunk push` again.

## Folder structure

```
Sources/HKNetworkKit/
    Core/            APIClient, NetworkClient, configuration, HTTP primitives, errors
    Request/         Endpoint, RequestBody, MultipartFormData, URLRequestBuilder
    Response/        NetworkResponse, ResponseValidator
    Authentication/  Bearer / Basic / API-key providers, token refresh
    Interceptor/     RequestInterceptor (adapt + process)
    Middleware/      Observability hooks, MetricsMiddleware
    Logger/          NetworkLogger, ConsoleLogger, curl builder
    Retry/           RetryPolicy, backoff strategies
    Reachability/    NetworkReachability (NWPathMonitor-based connectivity)
    Cache/           NetworkCachePolicy
    Security/        ServerTrustEvaluator (SSL/public-key pinning)
    Utilities/       Coders, TransferProgress
    Extensions/      Encodable/Data JSON helpers

Sources/HKNetworkKitImage/   (optional product — dependency-free image loading)
    PlatformImage, ImageCache, ImagePipeline, WebImageLoader,
    UIImageView+WebImage (UIKit), NetworkImage (SwiftUI)

Sources/KeyboardKit/       (optional product — iOS keyboard handling)
    KeyboardManager (+Toolbar), UIView+Keyboard, View+DismissKeyboard (SwiftUI)
```

## Quick start

### 1. Configure the client

```swift
import HKNetworkKit

let auth = BearerTokenProvider(token: "initial") {
    // Called automatically on a 401. Return a fresh token, or nil to fail.
    try await AuthService.refreshAccessToken()
}

let config = NetworkConfiguration(
    baseURL: URL(string: "https://api.example.com")!,
    defaultHeaders: ["User-Agent": "MyApp/1.0"],
    timeout: 30,
    coders: .snakeCase,
    retryPolicy: DefaultRetryPolicy(maxRetryCount: 2,
                                    strategy: .exponential(base: 0.5, maxDelay: 8)),
    logger: ConsoleLogger(level: .debug, logsCurl: true),
    authenticationProvider: auth,
    interceptors: [HeaderInjectionInterceptor(headers: ["X-Client": "ios"])],
    middlewares: [MetricsMiddleware { metric in Analytics.track(metric) }],
    serverTrustEvaluator: PublicKeyPinningEvaluator(
        pinnedKeyHashes: ["api.example.com": ["aBcD…base64-sha256…="]]
    )
)

let client: APIClient = NetworkClient(configuration: config)
```

### 2. Define endpoints

```swift
enum UserAPI {
    struct Get: Endpoint {
        let id: Int
        var path: String { "/users/\(id)" }
    }

    struct Create: Endpoint {
        let body: RequestBody
        var path: String { "/users" }
        var method: HTTPMethod { .post }
        init(name: String) { body = .json(["name": name]) }
    }
}
```

#### Easy mode: `EndpointProtocol` (string-based)

For quick adoption you can skip typed endpoints entirely and declare a plain,
string-based enum. HKNetworkKit bridges it into a full request for you (splitting
any `?query` out of the path, mapping the method string, etc.):

```swift
enum AppEndpoint: EndpointProtocol {
    case login, getProfile, scans(page: Int)

    var baseURL: String { "https://api.example.com" }
    var endpoint: String {
        switch self {
        case .login:        return "/auth/login"
        case .getProfile:   return "/me"
        case .scans(let p): return "/scans?page=\(p)"
        }
    }
    var method: String { self == .login ? "POST" : "GET" }
    var headers: [String: String] { ["Authorization": "Bearer \(token)"] }
}

// Pass the case straight to the client — no adapter needed:
let user: User = try await client.send(AppEndpoint.getProfile)
let created: User = try await client.send(AppEndpoint.login, body: jsonData)
let raw = try await client.sendRaw(AppEndpoint.scans(page: 2))
```

Use `Endpoint` (above) when you want typed methods, multipart bodies, or
per-request cache/timeout control; use `EndpointProtocol` when you just want to
get going fast.

### 3. Make requests

```swift
// GET + decode
let user: NetworkResponse<User> = try await client.send(UserAPI.Get(id: 1), as: User.self)
print(user.value, user.statusCode)

// POST
let created: User = try await client.send(UserAPI.Create(name: "Ada"))

// Raw data
let raw = try await client.sendRaw(UserAPI.Get(id: 1))
```

### 4. Upload an image with progress

```swift
var form = MultipartFormData()
form.append(jpegData, name: "avatar", fileName: "me.jpg", mimeType: "image/jpeg")

struct UploadAvatar: Endpoint {
    let body: RequestBody
    var path: String { "/me/avatar" }
    var method: HTTPMethod { .post }
}

let result = try await client.upload(
    UploadAvatar(body: .multipart(form)),
    as: UploadResult.self,
    onProgress: { progress in
        print("Uploaded \(progress.fraction.map { Int($0 * 100) } ?? 0)%")
    }
)
```

### 5. Download a file with progress

```swift
struct DownloadReport: Endpoint {
    var path: String { "/reports/2026.pdf" }
    var accept: String? { "application/pdf" }
}

let (fileURL, response) = try await client.download(DownloadReport()) { progress in
    print("Downloaded \(progress.completedBytes)/\(progress.totalBytes)")
}
```

### 6. Handle errors, cancellation, and retries

```swift
let task = Task {
    do {
        let user: User = try await client.send(UserAPI.Get(id: 1))
        return user
    } catch let error as APIError {
        switch error {
        case .unauthorized:        // token refresh already attempted automatically
        case .notFound:            // 404
        case .rateLimited(let retryAfter, _): print("retry after \(retryAfter ?? 0)")
        case .network, .timeout:   // transport problems (auto-retried per policy)
        default: break
        }
        throw error
    }
}

task.cancel()  // → throws APIError.cancelled
```

### 7. Use it in UIKit

Call the client from a `UIViewController` inside a `Task`. Hop to the main actor
to update UI; cancel the task in `deinit` or on disappearance.

```swift
import UIKit
import HKNetworkKit
import HKNetworkKitImage   // for the image view helper

final class ProfileViewController: UIViewController {
    private let client: APIClient
    private let nameLabel = UILabel()
    private let avatarView = UIImageView()
    private let spinner = UIActivityIndicatorView(style: .large)
    private var loadTask: Task<Void, Never>?

    init(client: APIClient) {
        self.client = client
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        load(userID: 1)
    }

    private func load(userID: Int) {
        spinner.startAnimating()
        loadTask = Task { @MainActor in
            defer { spinner.stopAnimating() }
            do {
                let user = try await client.send(UserAPI.Get(id: userID), as: User.self).value
                nameLabel.text = user.name
                avatarView.setImage(fromURL: user.avatarURL)   // HKNetworkKitImage helper
            } catch is CancellationError {
                // view went away — ignore
            } catch let error as APIError {
                presentAlert(error.localizedDescription)
            } catch {
                presentAlert("\(error)")
            }
        }
    }

    private func presentAlert(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    deinit { loadTask?.cancel() }
}
```

### 8. Use it in SwiftUI

Drive a view with an `@MainActor` view model that exposes a simple state enum.
The view switches on the state; `.task` auto-cancels the load when the view
disappears.

```swift
import SwiftUI
import HKNetworkKit
import HKNetworkKitImage

@MainActor
final class ProfileViewModel: ObservableObject {
    enum State { case idle, loading, loaded(User), failed(String) }

    @Published private(set) var state: State = .idle
    private let client: APIClient

    init(client: APIClient) { self.client = client }

    func load(userID: Int) async {
        state = .loading
        do {
            let user = try await client.send(UserAPI.Get(id: userID), as: User.self).value
            state = .loaded(user)
        } catch {
            state = .failed((error as? APIError)?.localizedDescription ?? "\(error)")
        }
    }
}

struct ProfileView: View {
    @StateObject private var model: ProfileViewModel

    init(client: APIClient) {
        _model = StateObject(wrappedValue: ProfileViewModel(client: client))
    }

    var body: some View {
        Group {
            switch model.state {
            case .idle, .loading:
                ProgressView()
            case .loaded(let user):
                VStack(spacing: 12) {
                    NetworkImage(url: user.avatarURL)
                        .frame(width: 96, height: 96)
                        .clipShape(Circle())
                    Text(user.name).font(.headline)
                }
            case .failed(let message):
                VStack(spacing: 8) {
                    Text("Failed to load").font(.headline)
                    Text(message).font(.caption).foregroundStyle(.secondary)
                    Button("Retry") { Task { await model.load(userID: 1) } }
                }
            }
        }
        .task { await model.load(userID: 1) }   // runs on appear, cancels on disappear
    }
}
```

> Both examples assume a `User` with an `avatarURL` and the `UserAPI.Get`
> endpoint from the sections above, plus a shared `client: APIClient` injected
> from your app's composition root.

## Network reachability

A dependency-free, easier-to-use replacement for `Reachability.swift`, built on
Apple's `Network` framework (`NWPathMonitor`).

```swift
// Shared singleton — already monitoring on first access:
if NetworkReachability.shared.isConnected { /* ... */ }
print(NetworkReachability.shared.connection)   // .wifi / .cellular / .ethernet / .other / .unavailable

// Closure callback (fires on every change, on a background queue):
NetworkReachability.shared.onChange = { connection in
    print("Now on \(connection) — online: \(connection.isOnline)")
}

// async/await stream:
for await connection in NetworkReachability.shared.changes {
    updateBanner(isOffline: !connection.isOnline)
}

// Suspend a flow until connectivity returns:
await NetworkReachability.shared.waitUntilConnected()

// Inspect path quality:
NetworkReachability.shared.isExpensive    // cellular / hotspot
NetworkReachability.shared.isConstrained  // Low Data Mode
```

### Fail fast when offline

Hand a monitor to the client and requests will throw `APIError.network`
immediately (before touching the transport) while offline:

```swift
let reachability = NetworkReachability.shared

let config = NetworkConfiguration(
    baseURL: URL(string: "https://api.example.com")!,
    reachability: reachability,
    failsWhenUnreachable: true
)
```

## Image loading (`HKNetworkKitImage`)

A custom, **dependency-free** image loader (memory + disk cache, automatic
de-duplication of concurrent requests for the same URL) with the same ergonomics
as SDWebImage. Add the `HKNetworkKitImage` product to your target to use it.

### UIKit

```swift
import HKNetworkKitImage

// Exactly the API you asked for — plus a built-in activity indicator,
// cache-aware fast path, and automatic cancellation on cell reuse:
avatarView.setImage(fromURL: user.avatarURL)
avatarView.loadImage(fromURL: user.avatarURL, placeholder: UIImage(named: "ph"))

// With completion:
avatarView.setImage(fromURL: url) { image, error in /* ... */ }

// async/await:
try await avatarView.setImage(fromURL: url)

// Buttons too:
button.setImage(fromURL: iconURL, for: .normal)

// Cancel manually (also happens automatically when you start a new load):
avatarView.cancelImageLoad()
```

### SwiftUI

```swift
import HKNetworkKitImage

// Default spinner placeholder:
NetworkImage(url: user.avatarURL)
    .frame(width: 80, height: 80)
    .clipShape(Circle())

// Custom placeholder:
NetworkImage(url: product.imageURL) {
    Color.gray.opacity(0.2)
}
```

### Plain Swift / cache control

```swift
let image = try await WebImageLoader.image(from: "https://…/photo.jpg")  // UIImage / NSImage
WebImageLoader.prefetch(urls)            // warm the cache ahead of time
WebImageLoader.cachedImage(for: url)     // synchronous memory hit, or nil
WebImageLoader.clearMemoryCache()
WebImageLoader.clearDiskCache()
```

> The core `HKNetworkKit` library has **zero** third-party dependencies. Image
> loading lives in the separate `HKNetworkKitImage` product, also dependency-free,
> built on `URLSession`, `NSCache`, `CryptoKit`, UIKit and SwiftUI.

## Keyboard handling (`KeyboardKit`)

A custom, **dependency-free** alternative to IQKeyboardManagerSwift for UIKit
(iOS). Enable it once and every text field in the app is kept above the keyboard,
gets a Previous/Next/Done toolbar, and dismisses on tap-outside — no per-screen code.

```swift
import KeyboardKit

// In AppDelegate / SceneDelegate:
KeyboardManager.shared.isEnabled = true

// Optional tweaks:
KeyboardManager.shared.keyboardDistanceFromTextField = 12
KeyboardManager.shared.resignOnTouchOutside = true
KeyboardManager.shared.isToolbarEnabled = true
KeyboardManager.shared.toolbarDoneTitle = "Done"
KeyboardManager.shared.toolbarTintColor = .systemBlue
```

How it works: observes the keyboard + begin-editing notifications, finds the
active responder, and either adjusts the enclosing `UIScrollView`'s content inset
(scrolling the field visible) or slides the view controller's view up — animated
with the keyboard's own duration and curve, then restored on dismiss.

### Per-screen opt-out

Disable handling for specific view controllers (e.g. one with its own custom
keyboard layout):

```swift
KeyboardManager.shared.disable(for: ChatViewController.self)
KeyboardManager.shared.enable(for: ChatViewController.self)   // re-enable later
```

### SwiftUI tap-to-dismiss

For SwiftUI screens, dismiss the keyboard on tap without disturbing controls:

```swift
import KeyboardKit

Form { … }
    .dismissKeyboardOnTap()

// Or imperatively:
KeyboardDismisser.dismiss()
```

### Full example

**1. Enable once at launch:**

```swift
import UIKit
import KeyboardKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        let keyboard = KeyboardManager.shared
        keyboard.isEnabled = true                       // turn everything on
        keyboard.keyboardDistanceFromTextField = 12
        keyboard.resignOnTouchOutside = true            // tap outside to dismiss
        keyboard.isToolbarEnabled = true                // Previous / Next / Done bar
        keyboard.toolbarTintColor = .systemBlue
        keyboard.toolbarDoneTitle = "Done"

        // Opt a specific screen out of all handling:
        keyboard.disable(for: OTPViewController.self)
        return true
    }
}
```

**2. UIKit — a scrolling form. No keyboard code in the controller at all:**

```swift
import UIKit

final class SignUpViewController: UIViewController {
    private let scrollView = UIScrollView()
    private let nameField = UITextField()
    private let emailField = UITextField()
    private let passwordField = UITextField()

    override func viewDidLoad() {
        super.viewDidLoad()
        [nameField, emailField, passwordField].forEach {
            $0.borderStyle = .roundedRect
        }
        passwordField.isSecureTextEntry = true

        let stack = UIStackView(arrangedSubviews: [nameField, emailField, passwordField])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
        // KeyboardKit automatically:
        //  • insets the scroll view + scrolls the active field into view,
        //  • adds a Previous/Next/Done toolbar wired across the three fields,
        //  • dismisses on tap outside.
    }
}
```

**3. SwiftUI — tap anywhere to dismiss:**

```swift
import SwiftUI
import KeyboardKit

struct SignUpView: View {
    @State private var name = ""
    @State private var email = ""

    var body: some View {
        Form {
            TextField("Name", text: $name)
            TextField("Email", text: $email)
            Button("Continue") { /* … */ }      // still tappable
        }
        .dismissKeyboardOnTap()
    }
}
```

> Covers the 90% case (avoidance, distance, tap-to-dismiss, Prev/Next/Done
> toolbar, per-VC opt-out, SwiftUI helper). It does **not** include IQ's
> method-swizzling, placeholder `IQTextView`, or per-orientation table quirks.
> iOS only.

## Testing

Inject a `MockURLSession` (conforming to `URLSessionProtocol`) to test without the network:

```swift
let session = MockURLSession()
session.enqueue(.init(data: Data(#"{"id":1,"name":"Ada"}"#.utf8)))
let client = NetworkClient(configuration: config, session: session)
let user: User = try await client.send(UserAPI.Get(id: 1))
```

See `Tests/HKNetworkKitTests` for full examples covering decoding, retries, token refresh,
multipart upload, and HTTPS enforcement.

## Requirements

- Swift 6.0+, iOS 15+ / macOS 12+ / tvOS 15+ / watchOS 8+
