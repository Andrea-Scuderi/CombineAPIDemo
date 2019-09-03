import XCTest
import Foundation
import Combine

@testable import CombineAPIDemo

class Mocks {
    let user = User(name: "name",
                    email: "email",
                    password: "password",
                    verifyPassword: "password")
    let todo = Todo(id: 1, title: "test1")
    
    let authorization = "ZW1haWw6cGFzc3dvcmQ="

    let invalidResponse = URLResponse(url: URL(string: "http://localhost:8080")!,
                                      mimeType: nil,
                                      expectedContentLength: 0,
                                      textEncodingName: nil)
    
    let validResponse = HTTPURLResponse(url: URL(string: "http://localhost:8080")!,
                                        statusCode: 200,
                                        httpVersion: nil,
                                        headerFields: nil)
    
    let invalidResponse300 = HTTPURLResponse(url: URL(string: "http://localhost:8080")!,
                                           statusCode: 300,
                                           httpVersion: nil,
                                           headerFields: nil)
    let invalidResponse401 = HTTPURLResponse(url: URL(string: "http://localhost:8080")!,
                                             statusCode: 401,
                                             httpVersion: nil,
                                             headerFields: nil)
    
    let networkError = NSError(domain: "NSURLErrorDomain",
                               code: -1004, //kCFURLErrorCannotConnectToHost
                               userInfo: nil)
    
}

struct Fixtures {
    static let createUserResponse = """
            { "id": 1,
              "email": "email",
              "name": "name"}
    """
    
    static let tokenResponse = """
    {
        "string": "mytoken"
    }
    """
    
    static let todoResponse = """
    {
        "id": 1,
        "title": "test"
    }
    """
    
    static let todosResponse = """
    [{
        "id": 1,
        "title": "test"
    },
    {
        "id": 2,
        "title": "test 2"
    }]
    """
}

@available(OSX 10.15, iOS 13.0, *)
final class CombineAPIDemoTests: XCTestCase {
    
    let testTimeout: TimeInterval = 1
    
    var mocks: Mocks!
    var customPublisher: APISessionDataPublisher!
    
    override func setUp() {
        // URLProtocolMock.setup()
        self.mocks = Mocks()
        
        // now set up a configuration to use our mock
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolMock.self]
        
        // and create the URLSession from that
        let session = URLSession(configuration: config)
        customPublisher = APISessionDataPublisher(session: session)
    }
    
    override func tearDown() {
        self.mocks = nil
        
        //Restore the default publisher
        APIDemo.publisher = APISessionDataPublisher()
        
        URLProtocolMock.response = nil
        URLProtocolMock.error = nil
        URLProtocolMock.testURLs = [URL?: Data]()
    }
    
    func testBaseURL() {
        XCTAssertEqual(APIDemo.baseURL, "http://localhost:8080")
    }
    
    func testDefaultHeaders() {
        XCTAssertEqual(APIDemo.defaultHeaders["Content-Type"], "application/json")
        XCTAssertEqual(APIDemo.defaultHeaders["cache-control"], "no-cache")
        XCTAssertEqual(APIDemo.defaultHeaders.count, 2)
    }
    
    func testBuildHeaders() {
        let headers = APIDemo.buildHeaders(key: "key", value: "value")
        XCTAssertEqual(headers["Content-Type"], "application/json")
        XCTAssertEqual(headers["cache-control"], "no-cache")
        XCTAssertEqual(headers["key"], "value")
        XCTAssertEqual(headers.count, 3)
    }
    
    func testBasicAuthorization() {
        let authorization = APIDemo.basicAuthorization(email: "email", password: "password")
        XCTAssertEqual(authorization, "ZW1haWw6cGFzc3dvcmQ=")
    }
    
    func testPostUserDTP() {
        let future = try? APIDemo.postUserDTP(user: self.mocks.user)
        let request =  future?.request
        XCTAssertEqual(request?.url?.absoluteString, APIDemo.baseURL + "/users")
        XCTAssertEqual(request?.httpMethod, "POST")
        XCTAssertEqual(request?.allHTTPHeaderFields?.count, APIDemo.defaultHeaders.count)
        XCTAssertEqual(request?.timeoutInterval, APIDemo.timeoutInterval)
        XCTAssertNotNil(request?.httpBody)
        if let body = request?.httpBody {
            let decoder = JSONDecoder()
            let user = try? decoder.decode(User.self, from: body)
            XCTAssertNotNil(user)
        }
    }
    
    func testPostLoginDTP() {
        let future = APIDemo.postLoginDTP(email: "email", password: "password")
        let request =  future.request
        XCTAssertEqual(request.url?.absoluteString, APIDemo.baseURL + "/login")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.allHTTPHeaderFields?.count, APIDemo.defaultHeaders.count + 1)
        let authorization = "Basic \(APIDemo.basicAuthorization(email: "email", password: "password"))"
        XCTAssertEqual(request.allHTTPHeaderFields?["Authorization"], authorization)
        XCTAssertEqual(request.timeoutInterval, APIDemo.timeoutInterval)
        XCTAssertNil(request.httpBody)
    }
    
    func testPostTodoDTP() {
        let future = APIDemo.postTodoDTP(authToken: self.mocks.authorization,
                                      body: self.mocks.todo)
        let request =  future.request
        XCTAssertEqual(request.url?.absoluteString, APIDemo.baseURL + "/todos")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.allHTTPHeaderFields?.count, APIDemo.defaultHeaders.count + 1)
        let authorization = "Bearer \(self.mocks.authorization)"
        XCTAssertEqual(request.allHTTPHeaderFields?["Authorization"], authorization)
        XCTAssertEqual(request.timeoutInterval, APIDemo.timeoutInterval)
        XCTAssertNotNil(request.httpBody)
        if let body = request.httpBody {
            let decoder = JSONDecoder()
            let todo = try? decoder.decode(Todo.self, from: body)
            XCTAssertNotNil(todo)
        }
    }
    
    func testGetTodoDTP() {
        let future: URLSession.DataTaskPublisher = APIDemo.getTodoDTP(authToken: self.mocks.authorization)
        let request =  future.request
        XCTAssertEqual(request.url?.absoluteString, APIDemo.baseURL + "/todos")
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.allHTTPHeaderFields?.count, APIDemo.defaultHeaders.count + 1)
        let authorization = "Bearer \(self.mocks.authorization)"
        XCTAssertEqual(request.allHTTPHeaderFields?["Authorization"], authorization)
        XCTAssertEqual(request.timeoutInterval, APIDemo.timeoutInterval)
        XCTAssertNil(request.httpBody)
    }
    
    func testDeleteTodoDTP() {
        let future: URLSession.DataTaskPublisher = APIDemo.deleteTodoDTP(authToken: self.mocks.authorization, id: 1)
        let request =  future.request
        XCTAssertEqual(request.url?.absoluteString, APIDemo.baseURL + "/todos/1")
        XCTAssertEqual(request.httpMethod, "DELETE")
        XCTAssertEqual(request.allHTTPHeaderFields?.count, APIDemo.defaultHeaders.count + 1)
        let authorization = "Bearer \(self.mocks.authorization)"
        XCTAssertEqual(request.allHTTPHeaderFields?["Authorization"], authorization)
        XCTAssertEqual(request.timeoutInterval, APIDemo.timeoutInterval)
        XCTAssertNil(request.httpBody)
    }
    
    func testValidate() {
        XCTAssertThrowsError(try APIDemo.validate(Data(), self.mocks.invalidResponse))
        XCTAssertThrowsError(try APIDemo.validate(Data(), self.mocks.invalidResponse300!))
        XCTAssertThrowsError(try APIDemo.validate(Data(), self.mocks.invalidResponse401!))
        
        let data = try? APIDemo.validate(Data(), self.mocks.validResponse!)
        XCTAssertNotNil(data)
    }
    
    func evalValidResponseTest<T:Publisher>(publisher: T?) -> (expectations:[XCTestExpectation], cancellable: AnyCancellable?) {
        XCTAssertNotNil(publisher)
        
        let expectationFinished = expectation(description: "finished")
        let expectationReceive = expectation(description: "receiveValue")
        let expectationFailure = expectation(description: "failure")
        expectationFailure.isInverted = true
        
        let cancellable = publisher?.sink (receiveCompletion: { (completion) in
            switch completion {
            case .failure(let error):
                print("--TEST ERROR--")
                print(error.localizedDescription)
                print("------")
                expectationFailure.fulfill()
            case .finished:
                expectationFinished.fulfill()
            }
        }, receiveValue: { response in
            XCTAssertNotNil(response)
            print(response)
            expectationReceive.fulfill()
        })
        return (expectations: [expectationFinished, expectationReceive, expectationFailure],
                cancellable: cancellable)
    }
    
    func evalInvalidResponseTest<T:Publisher>(publisher: T?) -> (expectations:[XCTestExpectation], cancellable: AnyCancellable?) {
        XCTAssertNotNil(publisher)
        
        let expectationFinished = expectation(description: "Invalid.finished")
        expectationFinished.isInverted = true
        let expectationReceive = expectation(description: "Invalid.receiveValue")
        expectationReceive.isInverted = true
        let expectationFailure = expectation(description: "Invalid.failure")
        
        let cancellable = publisher?.sink (receiveCompletion: { (completion) in
            switch completion {
            case .failure(let error):
                print("--TEST FULFILLED--")
                print(error.localizedDescription)
                print("------")
                expectationFailure.fulfill()
            case .finished:
                expectationFinished.fulfill()
            }
        }, receiveValue: { response in
            XCTAssertNotNil(response)
            print(response)
            expectationReceive.fulfill()
        })
         return (expectations: [expectationFinished, expectationReceive, expectationFailure],
                       cancellable: cancellable)
    }
    
    func testCreate() {

        //Setup fixture
        let usersURL = URL(string: APIDemo.baseURL + "/users")
        URLProtocolMock.testURLs = [usersURL: Data(Fixtures.createUserResponse.utf8)]
        
        //1) When is valid
        APIDemo.publisher = customPublisher
        URLProtocolMock.response = mocks.validResponse
        let publisher = APIDemo.create(user: self.mocks.user)

        let validTest = evalValidResponseTest(publisher: publisher)
        wait(for: validTest.expectations, timeout: testTimeout)
        validTest.cancellable?.cancel()
        
        //2) When has invalid response
        URLProtocolMock.response = mocks.invalidResponse
        let publisher2 = APIDemo.create(user: self.mocks.user)
        let invalidTest = evalInvalidResponseTest(publisher: publisher2)
        wait(for: invalidTest.expectations, timeout: testTimeout)
        invalidTest.cancellable?.cancel()
        
        //3) When has invalid data and valid response
        URLProtocolMock.testURLs[usersURL] = Data("{{}".utf8)
        URLProtocolMock.response = mocks.validResponse
        
        let publisher3 = APIDemo.create(user: self.mocks.user)
        let invalidTest3 = evalInvalidResponseTest(publisher: publisher3)
        wait(for: invalidTest3.expectations, timeout: testTimeout)
        invalidTest3.cancellable?.cancel()
        
        //4) Network Failure
        URLProtocolMock.response = mocks.validResponse
        URLProtocolMock.error = mocks.networkError
        
        let publisher4 = APIDemo.create(user: self.mocks.user)
        let invalidTest4 = evalInvalidResponseTest(publisher: publisher4)
        wait(for: invalidTest4.expectations, timeout: testTimeout)
        invalidTest4.cancellable?.cancel()
    }
    
    func testPostLogin() {
        
        //Setup fixture
        let usersURL = URL(string: APIDemo.baseURL + "/login")
        URLProtocolMock.testURLs = [usersURL: Data(Fixtures.tokenResponse.utf8)]
        
        //1) When is valid
        APIDemo.publisher = customPublisher
        URLProtocolMock.response = mocks.validResponse
        let publisher = APIDemo.login(email: "email", password: "password")

        let validTest = evalValidResponseTest(publisher: publisher)
        wait(for: validTest.expectations, timeout: testTimeout)
        validTest.cancellable?.cancel()
        
        //2) When has invalid response
        URLProtocolMock.response = mocks.invalidResponse
        let publisher2 = APIDemo.login(email: "email", password: "password")
        let invalidTest = evalInvalidResponseTest(publisher: publisher2)
        wait(for: invalidTest.expectations, timeout: testTimeout)
        invalidTest.cancellable?.cancel()
        
        //3) When has invalid data and valid response
        URLProtocolMock.testURLs[usersURL] = Data("{{}".utf8)
        URLProtocolMock.response = mocks.validResponse
        
        let publisher3 = APIDemo.login(email: "email", password: "password")
        let invalidTest3 = evalInvalidResponseTest(publisher: publisher3)
        wait(for: invalidTest3.expectations, timeout: testTimeout)
        invalidTest3.cancellable?.cancel()
        
        //4) Network Failure
        URLProtocolMock.response = mocks.validResponse
        URLProtocolMock.error = mocks.networkError
        
        let publisher4 = APIDemo.login(email: "email", password: "password")
        let invalidTest4 = evalInvalidResponseTest(publisher: publisher4)
        wait(for: invalidTest4.expectations, timeout: testTimeout)
        invalidTest4.cancellable?.cancel()
    }
    
    func testPostTodo() {
        
        //Setup fixture
        let todo = Todo(id: 1, title: "test")
        let usersURL = URL(string: APIDemo.baseURL + "/todos")
        URLProtocolMock.testURLs = [usersURL: Data(Fixtures.todoResponse.utf8)]
        
        //1) When is valid
        APIDemo.publisher = customPublisher
        URLProtocolMock.response = mocks.validResponse
        let publisher = APIDemo.postTodo(authToken: "token", todo: todo)

        let validTest = evalValidResponseTest(publisher: publisher)
        wait(for: validTest.expectations, timeout: testTimeout)
        validTest.cancellable?.cancel()
        
        //2) When has invalid response
        URLProtocolMock.response = mocks.invalidResponse
        let publisher2 = APIDemo.postTodo(authToken: "token", todo: todo)
        let invalidTest = evalInvalidResponseTest(publisher: publisher2)
        wait(for: invalidTest.expectations, timeout: testTimeout)
        invalidTest.cancellable?.cancel()
        
        //3) When has invalid data and valid response
        URLProtocolMock.testURLs[usersURL] = Data("{{}".utf8)
        URLProtocolMock.response = mocks.validResponse
        
        let publisher3 = APIDemo.postTodo(authToken: "token", todo: todo)
        let invalidTest3 = evalInvalidResponseTest(publisher: publisher3)
        wait(for: invalidTest3.expectations, timeout: testTimeout)
        invalidTest3.cancellable?.cancel()
        
        //4) Network Failure
        URLProtocolMock.response = mocks.validResponse
        URLProtocolMock.error = mocks.networkError
        
        let publisher4 = APIDemo.postTodo(authToken: "token", todo: todo)
        let invalidTest4 = evalInvalidResponseTest(publisher: publisher4)
        wait(for: invalidTest4.expectations, timeout: testTimeout)
        invalidTest4.cancellable?.cancel()
    }
    
    func testGetTodo() {
        
        //Setup fixture
        let usersURL = URL(string: APIDemo.baseURL + "/todos")
        URLProtocolMock.testURLs = [usersURL: Data(Fixtures.todosResponse.utf8)]
        
        //1) When is valid
        APIDemo.publisher = customPublisher
        URLProtocolMock.response = mocks.validResponse
        let publisher = APIDemo.getTodo(authToken: "token")

        let validTest = evalValidResponseTest(publisher: publisher)
        wait(for: validTest.expectations, timeout: testTimeout)
        validTest.cancellable?.cancel()
        
        //2) When has invalid response
        URLProtocolMock.response = mocks.invalidResponse
        let publisher2 = APIDemo.getTodo(authToken: "token")
        let invalidTest = evalInvalidResponseTest(publisher: publisher2)
        wait(for: invalidTest.expectations, timeout: testTimeout)
        invalidTest.cancellable?.cancel()
        
        //3) When has invalid data and valid response
        URLProtocolMock.testURLs[usersURL] = Data("{{}".utf8)
        URLProtocolMock.response = mocks.validResponse
        
        let publisher3 = APIDemo.getTodo(authToken: "token")
        let invalidTest3 = evalInvalidResponseTest(publisher: publisher3)
        wait(for: invalidTest3.expectations, timeout: testTimeout)
        invalidTest3.cancellable?.cancel()
        
        //4) Network Failure
        URLProtocolMock.response = mocks.validResponse
        URLProtocolMock.error = mocks.networkError
        
        let publisher4 = APIDemo.getTodo(authToken: "token")
        let invalidTest4 = evalInvalidResponseTest(publisher: publisher4)
        wait(for: invalidTest4.expectations, timeout: testTimeout)
        invalidTest4.cancellable?.cancel()
    }
    
    func testDeleteTodo() {
        
        //Setup fixture
        let usersURL = URL(string: APIDemo.baseURL + "/todos/1")
        URLProtocolMock.testURLs = [usersURL: Data(Fixtures.todoResponse.utf8)]
        
        //1) When is valid
        APIDemo.publisher = customPublisher
        URLProtocolMock.response = mocks.validResponse
        let publisher = APIDemo.deleteTodo(authToken: "token", id: 1)

        let validTest = evalValidResponseTest(publisher: publisher)
        wait(for: validTest.expectations, timeout: testTimeout)
        validTest.cancellable?.cancel()
        
        //2) When has invalid response
        URLProtocolMock.response = mocks.invalidResponse
        let publisher2 = APIDemo.deleteTodo(authToken: "token", id: 1)
        let invalidTest = evalInvalidResponseTest(publisher: publisher2)
        wait(for: invalidTest.expectations, timeout: testTimeout)
        invalidTest.cancellable?.cancel()
        
        //3) When has invalid data and valid response
        URLProtocolMock.testURLs[usersURL] = Data("{{}".utf8)
        URLProtocolMock.response = mocks.validResponse
        
        let publisher3 = APIDemo.deleteTodo(authToken: "token", id: 1)
        let invalidTest3 = evalInvalidResponseTest(publisher: publisher3)
        wait(for: invalidTest3.expectations, timeout: testTimeout)
        invalidTest3.cancellable?.cancel()
        
        //4) Network Failure
        URLProtocolMock.response = mocks.validResponse
        URLProtocolMock.error = mocks.networkError
        
        let publisher4 = APIDemo.deleteTodo(authToken: "token", id: 1)
        let invalidTest4 = evalInvalidResponseTest(publisher: publisher4)
        wait(for: invalidTest4.expectations, timeout: testTimeout)
        invalidTest4.cancellable?.cancel()
    }
    
    static var allTests = [
        ("testBaseURL", testBaseURL),
        ("testDefaultHeaders", testDefaultHeaders),
        ("testBasicAuthorization", testBasicAuthorization),
        ("testBuildHeaders", testBuildHeaders),
        ("testPostUserDTP", testPostUserDTP),
        ("testPostLoginDTP", testPostLoginDTP),
        ("testPostTodoDTP", testPostTodoDTP),
        ("testGetTodoDTP", testGetTodoDTP),
        ("testDeleteTodoDTP", testDeleteTodoDTP),
        ("testValidate", testValidate),
        ("testCreate", testCreate),
        ("testPostLogin", testPostLogin),
        ("testPostTodo", testPostTodo),
        ("testGetTodo", testGetTodo),
        ("testDeleteTodo", testDeleteTodo)
    ]
}
