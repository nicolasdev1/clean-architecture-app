//
//  InfraTests.swift
//  InfraTests
//
//  Created by Nicolas Carvalho on 14/01/21.
//

import XCTest
import Data
import Infra
import Alamofire

class AlamofireAdapterTests: XCTestCase {
    // - MARK: Request Tests
    func test_post_should_make_request_with_valid_url_and_method() {
        let url = makeUrl()
        testRequestFor(url: url, data: makeValidData()) { request in
            XCTAssertEqual(url, request.url)
            XCTAssertEqual("POST", request.httpMethod)
            XCTAssertNotNil(request.httpBodyStream)
        }
    }
    
    func test_post_should_make_request_with_no_data() {
        testRequestFor(data: nil) { request in
            XCTAssertNil(request.httpBodyStream)
        }
    }
    
    // - MARK: Return Tests
    func test_post_should_complete_with_error_when_request_completes_with_error() {
        expectResult(.failure(.noConnectivity), when: (data: nil, response: nil, error: makeError()))
    }
    
    func test_post_should_complete_with_error_on_all_invalid_cases() {
        expectResult(.failure(.noConnectivity), when: (data: makeValidData(), response: makeHttpResponse(), error: makeError()))
        
        expectResult(.failure(.noConnectivity), when: (data: makeValidData(), response: nil, error: makeError()))
        
        expectResult(.failure(.noConnectivity), when: (data: makeValidData(), response: nil, error: nil))
        
        expectResult(.failure(.noConnectivity), when: (data: nil, response: makeHttpResponse(), error: makeError()))
        
        expectResult(.failure(.noConnectivity), when: (data: nil, response: makeHttpResponse(), error: nil))
        
        expectResult(.failure(.noConnectivity), when: (data: nil, response: nil, error: makeError()))
    }
    
    func test_post_should_complete_with_error_when_request_completes_with_non_200() {
        expectResult(.failure(.badRequest), when: (data: makeValidData(), response: makeHttpResponse(statusCode: 400), error: nil))
        
        expectResult(.failure(.badRequest), when: (data: makeValidData(), response: makeHttpResponse(statusCode: 450), error: nil))
        
        expectResult(.failure(.badRequest), when: (data: makeValidData(), response: makeHttpResponse(statusCode: 499), error: nil))
        
        expectResult(.failure(.serverError), when: (data: makeValidData(), response: makeHttpResponse(statusCode: 500), error: nil))
        
        expectResult(.failure(.serverError), when: (data: makeValidData(), response: makeHttpResponse(statusCode: 550), error: nil))
        
        expectResult(.failure(.serverError), when: (data: makeValidData(), response: makeHttpResponse(statusCode: 599), error: nil))
        
        expectResult(.failure(.unauthorized), when: (data: makeValidData(), response: makeHttpResponse(statusCode: 401), error: nil))
        
        expectResult(.failure(.forbidden), when: (data: makeValidData(), response: makeHttpResponse(statusCode: 403), error: nil))
        
        expectResult(.failure(.noConnectivity), when: (data: makeValidData(), response: makeHttpResponse(statusCode: 300), error: nil))
        
        expectResult(.failure(.noConnectivity), when: (data: makeValidData(), response: makeHttpResponse(statusCode: 100), error: nil))
    }
    
    func test_post_should_complete_with_data_when_request_completes_with_200() {
        expectResult(.success(makeValidData()), when: (data: makeValidData(), response: makeHttpResponse(), error: nil))
    }
    
    func test_post_should_complete_with_no_data_when_request_completes_with_204() {
        expectResult(.success(nil), when: (data: nil, response: makeHttpResponse(statusCode: 204), error: nil))
        
        expectResult(.success(nil), when: (data: makeEmptyData(), response: makeHttpResponse(statusCode: 204), error: nil))
        
        expectResult(.success(nil), when: (data: makeValidData(), response: makeHttpResponse(statusCode: 204), error: nil))
    }
}

// - MARK: Extension Tests
extension AlamofireAdapterTests {
    func makeSystemUnderTest(file: StaticString = #file, line: UInt = #line) -> AlamofireAdapter {
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [UrlProtocolStub.self]
        let session = Session(configuration: configuration)
        let systemUnderTest = AlamofireAdapter(session: session)
        checkMemoryLeak(for: systemUnderTest, file: file, line: line)
        return systemUnderTest
    }
    
    func testRequestFor(url: URL = makeUrl(), data: Data?, action: @escaping (URLRequest) -> Void) {
        let systemUnderTest = makeSystemUnderTest()
        let expec = expectation(description: "waiting")
        systemUnderTest.post(to: url, with: data) { _ in expec.fulfill() }
        var request: URLRequest?
        UrlProtocolStub.observeRequest { request = $0 }
        wait(for: [expec], timeout: 1)
        action(request!)
    }
    
    func expectResult(_ expectedResult: Result<Data?, HttpError>, when stub: (data: Data?, response: HTTPURLResponse?, error: Error?), file: StaticString = #file, line: UInt = #line) {
        let systemUnderTest = makeSystemUnderTest()
        UrlProtocolStub.simulate(data: stub.data, response: stub.response, error: stub.error)
        let expec = expectation(description: "waiting")
        systemUnderTest.post(to: makeUrl(), with: makeValidData()) { receivedResult in
            switch (expectedResult, receivedResult) {
            case (.failure(let expectedError), .failure(let receivedError)):
                XCTAssertEqual(expectedError, receivedError, file: file, line: line)
            case (.success(let expectedData), .success(let receivedData)):
                XCTAssertEqual(expectedData, receivedData, file: file, line: line)
            default:
                XCTFail("Expected \(expectedResult) got \(receivedResult) instead.")
            }
            expec.fulfill()
        }
        wait(for: [expec], timeout: 1)
    }
}