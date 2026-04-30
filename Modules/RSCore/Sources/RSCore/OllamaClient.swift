import Foundation

public final class OllamaClient: @unchecked Sendable {
    public static let shared = OllamaClient()

    private var baseURL: URL {
        if let urlString = UserDefaults.standard.string(forKey: "OllamaBaseURL"), let url = URL(string: urlString) {
            if urlString.hasSuffix("/api") || urlString.hasSuffix("/api/") {
                return url
            }
            return url.appendingPathComponent("api")
        }
        return URL(string: "http://localhost:11434/api")!
    }

    private var model: String {
        return UserDefaults.standard.string(forKey: "OllamaModel") ?? "llama3"
    }

    private var preferredLanguage: String {
        return UserDefaults.standard.string(forKey: "OllamaPreferredLanguage") ?? "Chinese"
    }

    private var translationCache = [String: String]()
    private var activeTasks = [String: URLSessionDataTask]()
    private var completionHandlers = [String: [(Result<String, Error>) -> Void]]()
    private var explicitRequests = Set<String>()
    
    private let cacheQueue = DispatchQueue(label: "com.netnewswire.ollamacache")

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300 // 5 minutes to prevent timeout
        config.timeoutIntervalForResource = 300
        return URLSession(configuration: config)
    }()

    public init() {}

    @discardableResult
    private func generate(prompt: String, completion: @escaping (Result<String, Error>) -> Void) -> URLSessionDataTask? {
        let url = baseURL.appendingPathComponent("generate")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "stream": false
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                let err = NSError(domain: "OllamaClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])
                completion(.failure(err))
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let responseText = json["response"] as? String {
                        completion(.success(responseText))
                    } else if let errorText = json["error"] as? String {
                        completion(.failure(NSError(domain: "OllamaClient", code: -1, userInfo: [NSLocalizedDescriptionKey: errorText])))
                    } else {
                        let raw = String(data: data, encoding: .utf8) ?? "Unknown"
                        completion(.failure(NSError(domain: "OllamaClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid API response: \(raw)"])))
                    }
                } else {
                    let raw = String(data: data, encoding: .utf8) ?? "Unknown"
                    completion(.failure(NSError(domain: "OllamaClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON format. Raw: \(raw)"])))
                }
            } catch {
                let raw = String(data: data, encoding: .utf8) ?? "Unknown"
                completion(.failure(NSError(domain: "OllamaClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse JSON. Raw: \(raw)"])))
            }
        }
        task.resume()
        return task
    }

    public func cachedTranslation(articleID: String) -> String? {
        var result: String?
        cacheQueue.sync {
            result = translationCache[articleID]
        }
        return result
    }

    public func translate(articleID: String, text: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard !text.isEmpty else {
            completion(.failure(NSError(domain: "OllamaClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "No text available"])))
            return
        }

        cacheQueue.async {
            if let cached = self.translationCache[articleID] {
                completion(.success(cached))
                return
            }
            
            self.explicitRequests.insert(articleID)

            if self.activeTasks[articleID] != nil {
                // Task is already running (e.g., from preload), attach completion handler
                var handlers = self.completionHandlers[articleID] ?? []
                handlers.append(completion)
                self.completionHandlers[articleID] = handlers
                return
            }

            let prompt = "Translate the following text to \(self.preferredLanguage). ONLY return the translated text and nothing else. Do not add any conversational filler, side notes, explanations, or multiple options. Provide exactly one translation:\n\n\(text)"
            
            self.completionHandlers[articleID] = [completion]
            
            let task = self.generate(prompt: prompt) { [weak self] result in
                self?.cacheQueue.async {
                    self?.activeTasks.removeValue(forKey: articleID)
                    self?.explicitRequests.remove(articleID)
                    
                    if case .success(let translation) = result {
                        self?.translationCache[articleID] = translation
                    }
                    
                    if let handlers = self?.completionHandlers.removeValue(forKey: articleID) {
                        for handler in handlers {
                            handler(result)
                        }
                    }
                }
            }
            
            if let task = task {
                self.activeTasks[articleID] = task
            }
        }
    }

    public func preloadTranslations(items: [(id: String, text: String)]) {
        let desiredIDs = Set(items.map { $0.id })
        
        cacheQueue.async {
            // Cancel active preloads that are no longer needed
            for (id, task) in self.activeTasks {
                if !desiredIDs.contains(id) && !self.explicitRequests.contains(id) {
                    task.cancel()
                    self.activeTasks.removeValue(forKey: id)
                    self.completionHandlers.removeValue(forKey: id)
                }
            }
            
            // Start new preloads
            for item in items {
                let id = item.id
                let text = item.text
                
                guard self.translationCache[id] == nil, self.activeTasks[id] == nil else {
                    continue
                }
                guard !text.isEmpty else { continue }
                
                let prompt = "Translate the following text to \(self.preferredLanguage). ONLY return the translated text and nothing else. Do not add any conversational filler, side notes, explanations, or multiple options. Provide exactly one translation:\n\n\(text)"
                
                let task = self.generate(prompt: prompt) { [weak self] result in
                    self?.cacheQueue.async {
                        self?.activeTasks.removeValue(forKey: id)
                        if case .success(let translation) = result {
                            self?.translationCache[id] = translation
                        }
                        if let handlers = self?.completionHandlers.removeValue(forKey: id) {
                            for handler in handlers {
                                handler(result)
                            }
                        }
                    }
                }
                
                if let task = task {
                    self.activeTasks[id] = task
                }
            }
        }
    }
}
