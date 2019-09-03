import Combine
import Foundation

enum APIError: Error {
    case invalidBody
    case invalidEndpoint
    case invalidURL
    case emptyData
    case invalidJSON
    case invalidResponse
    case statusCode(Int)
}

struct User: Codable {
    let name: String
    let email: String
    let password: String
    let verifyPassword: String
}

struct CreateUserResponse: Codable {
    let id: Int
    let email: String
    let name: String
}

struct Todo: Codable {
    let id: Int?
    let title: String
}

struct Token: Codable {
    let string: String
}

@available(OSX 10.15, iOS 13.0, *)
protocol APIDataTaskPublisher {
    func dataTaskPublisher(for request: URLRequest) -> URLSession.DataTaskPublisher
}

@available(OSX 10.15, iOS 13.0, *)
class APISessionDataPublisher: APIDataTaskPublisher {
    
    func dataTaskPublisher(for request: URLRequest) -> URLSession.DataTaskPublisher {
        return session.dataTaskPublisher(for: request)
    }
    
    var session: URLSession
    
    init(session: URLSession = URLSession.shared) {
        self.session = session
    }
}

@available(OSX 10.15, iOS 13.0, *)
struct APIDemo {
    
    static let baseURL = "http://localhost:8080"
    
    static let defaultHeaders = [
        "Content-Type": "application/json",
        "cache-control": "no-cache",
    ]
    
    static var timeoutInterval: TimeInterval = 10.0
    
    static var publisher: APIDataTaskPublisher = APISessionDataPublisher()
    
    internal static func buildHeaders(key: String, value: String) -> [String: String] {
        var headers = defaultHeaders
        headers[key] = value
        return headers
    }
    
    internal static func basicAuthorization(email: String, password: String) -> String {
        let loginString = String(format: "%@:%@", email, password)
        let loginData: Data = loginString.data(using: .utf8)!
        return loginData.base64EncodedString()
    }
    
    private static func buildPostUserRequest(user: User) -> URLRequest {
        let encoder = JSONEncoder()
        guard let postData = try? encoder.encode(user) else {
            fatalError("APIError.invalidEndpoint")
        }
        guard let url = URL(string: baseURL + "/users" ) else {
            fatalError("APIError.invalidEndpoint")
        }
        var request = URLRequest(url: url, timeoutInterval: timeoutInterval)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = defaultHeaders
        request.httpBody = postData as Data
        
        return request
    }
    
    internal static func postUserDTP(user: User) throws -> URLSession.DataTaskPublisher {
        let request = buildPostUserRequest(user: user)
        return publisher.dataTaskPublisher(for: request)
    }
        
    private static func buildLoginRequest(email: String, password: String) -> URLRequest {
        
        let base64LoginString = basicAuthorization(email: email, password: password)
        
        let headers = buildHeaders(key: "Authorization", value: "Basic \(base64LoginString)")
        
        guard let url = URL(string: baseURL + "/login" ) else {
            fatalError("APIError.invalidEndpoint")
        }
        var request = URLRequest(url: url, timeoutInterval: timeoutInterval)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = headers
        return request
    }
    
    internal static func postLoginDTP(email: String,password: String) -> URLSession.DataTaskPublisher {
        let request = buildLoginRequest(email: email, password: password)
        return publisher.dataTaskPublisher(for: request)
    }
    
    private static func buildPostTodoRequest(authToken: String, body: Todo) -> URLRequest {
        
        let headers = buildHeaders(key: "Authorization", value: "Bearer \(authToken)")
        let encoder = JSONEncoder()
        guard let postData = try? encoder.encode(body) else {
            fatalError("APIError.invalidBody")
        }
        guard let url = URL(string: baseURL + "/todos" ) else {
            fatalError("APIError.invalidEndpoint")
        }
        var request = URLRequest(url: url, timeoutInterval: timeoutInterval)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = headers
        request.httpBody = postData
        return request
    }

    internal static func postTodoDTP(authToken: String, body: Todo) -> URLSession.DataTaskPublisher {
        let request = buildPostTodoRequest(authToken: authToken, body: body)
        return publisher.dataTaskPublisher(for: request)
    }
    
    private static func buildGetTodoRequest(authToken: String) -> URLRequest {
        
        let headers = buildHeaders(key: "Authorization", value: "Bearer \(authToken)")
        guard let url = URL(string: baseURL + "/todos" ) else {
            fatalError("APIError.invalidEndpoint")
        }
        var request = URLRequest(url: url, timeoutInterval: timeoutInterval)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = headers
        return request
    }

    internal static func getTodoDTP(authToken: String) -> URLSession.DataTaskPublisher {
        let request = buildGetTodoRequest(authToken: authToken)
        return publisher.dataTaskPublisher(for: request)
    }

    private static func buildDeleteTodoRequest(authToken: String, id: Int) -> URLRequest {
        
        let headers = buildHeaders(key: "Authorization", value: "Bearer \(authToken)")
        guard let url = URL(string: baseURL + "/todos/\(id)" ) else {
            fatalError("APIError.invalidEndpoint")
        }
        var request = URLRequest(url: url, timeoutInterval: timeoutInterval)
        request.httpMethod = "DELETE"
        request.allHTTPHeaderFields = headers
        return request
    }

    internal static func deleteTodoDTP(authToken: String, id: Int) -> URLSession.DataTaskPublisher {
        let request = buildDeleteTodoRequest(authToken: authToken, id: id)
        return publisher.dataTaskPublisher(for: request)
    }
    
    
    internal static func validate(_ data: Data, _ response: URLResponse) throws -> Data {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw APIError.statusCode(httpResponse.statusCode)
        }
        return data
    }

    static func create(user: User) -> AnyPublisher<CreateUserResponse, Error>? {
        return try? postUserDTP(user: user)
            .tryMap{ try validate($0.data, $0.response) }
            .decode(type: CreateUserResponse.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
            
    static func login(email: String, password: String) -> AnyPublisher<Token, Error> {
        return postLoginDTP(email: email, password: password)
                .tryMap{ try validate($0.data, $0.response) }
                .decode(type: Token.self, decoder: JSONDecoder())
                .eraseToAnyPublisher()
    }

    static func postTodo(authToken: String, todo: Todo) -> AnyPublisher<Todo, Error> {
        return  postTodoDTP(authToken: authToken, body: todo)
                .tryMap{ try validate($0.data, $0.response) }
                .decode(type: Todo.self, decoder: JSONDecoder())
                .eraseToAnyPublisher()
    }

    static func getTodo(authToken: String) -> AnyPublisher<[Todo], Error> {
        return getTodoDTP(authToken: authToken)
                .tryMap{ try validate($0.data, $0.response) }
                .decode(type: [Todo].self, decoder: JSONDecoder())
                .eraseToAnyPublisher()
    }

    static func deleteTodo(authToken: String, id: Int) -> AnyPublisher<Todo, Error> {
        return deleteTodoDTP(authToken: authToken, id: id)
                .tryMap{ try validate($0.data, $0.response) }
                .decode(type: Todo.self, decoder: JSONDecoder())
                .eraseToAnyPublisher()
    }
}
