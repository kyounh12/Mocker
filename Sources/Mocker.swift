//
//  Mocker.swift
//  Rabbit
//
//  Created by Antoine van der Lee on 04/05/2017.
//  Copyright © 2017 WeTransfer. All rights reserved.
//

import Foundation

/// Can be used for registering Mocked data, returned by the `MockingURLProtocol`.
public struct Mocker {
    
    public enum HTTPVersion: String {
        case http1_0 = "HTTP/1.0"
        case http1_1 = "HTTP/1.1"
        case http2_0 = "HTTP/2.0"
    }
    
    /// The shared instance of the Mocker, can be used to register and return mocks.
    internal static var shared = Mocker()
    
    /// The HTTP Version to use in the mocked response.
    public static var httpVersion: HTTPVersion = HTTPVersion.http1_1
    
    /// If `allowListing` enabled, `Mocker` only handles urls containing strings in `allowedList`
    /// Else, `Mocker` handles urls except for urls containing strings in `deniedList`
    public static var allowListing: Bool = false
    
    /// If `debugOnly` is true, Mocker only handles requests when `DEBUG` flag exists
    public static var debugOnly: Bool = true
    
    /// The registrated mocks.
    private(set) var mocks: [Mock] = []
    
    /// URLs to handle for mocking.
    private(set) var allowedList: [String] = []
    private(set) var deniedList: [String] = []

    /// For Thread Safety access.
    private let queue = DispatchQueue(label: "mocker.mocks.access.queue", attributes: .concurrent)

    private init() {
        // Whenever someone is requesting the Mocker, we want the URL protocol to be activated.
        URLProtocol.registerClass(MockingURLProtocol.self)
    }
    
    /// Register new Mocked data. If a mock for the same URL and HTTPMethod exists, it will be overwritten.
    ///
    /// - Parameter mock: The Mock to be registered for future requests.
    public static func register(_ mock: Mock) {
        shared.queue.async(flags: .barrier) {
            /// Delete the Mock if it was already registered.
            shared.mocks.removeAll(where: { $0 == mock })
            shared.mocks.append(mock)
        }
    }
    
    /// Register an URL to ignore for mocking. This will let the URL work as if the Mocker doesn't exist.
    ///
    /// - Parameter url: The string  to deny.
    public static func deny(_ string: String) {
        shared.queue.async(flags: .barrier) {
            shared.deniedList.append(string)
        }
    }
    
    /// Register an URL to allow for mocking.
    ///
    /// - Parameter url: The string  to deny.
    public static func allow(_ string: String) {
        shared.queue.async(flags: .barrier) {
            shared.allowedList.append(string)
        }
    }
    
    /// Checks if the passed URL should be handled by the Mocker. If the URL is registered to be ignored, it will not handle the URL.
    ///
    /// - Parameter url: The URL to check for.
    /// - Returns: `true` if it should be mocked, `false` if the URL is registered as ignored.
    public static func shouldHandle(_ url: URL) -> Bool {
        shared.queue.sync {
            // Check if debug mode is enabled
            if debugOnly {
                #if !DEBUG
                return false
                #endif
            }

            let urlString: String = url.absoluteString
            if allowListing {
                return shared.allowedList.contains(where: { urlString.contains($0) })
            } else {
                return !shared.deniedList.contains(where: { urlString.contains($0) })
            }
        }
    }

    /// Removes all registered mocks. Use this method in your tearDown function to make sure a Mock is not used in any other test.
    public static func removeAll() {
        shared.queue.sync(flags: .barrier) {
            shared.mocks.removeAll()
        }
    }
    
    /// Retrieve a Mock for the given request. Matches on `request.url` and `request.httpMethod`.
    ///
    /// - Parameter request: The request to search for a mock.
    /// - Returns: A mock if found, `nil` if there's no mocked data registered for the given request.
    static func mock(for request: URLRequest) -> Mock? {
        shared.queue.sync {
            /// First check for specific URLs
            if let specificMock = shared.mocks.first(where: { $0 == request && $0.fileExtensions == nil }) {
                return specificMock
            }
            /// Second, check for generic file extension Mocks
            return shared.mocks.first(where: { $0 == request })
        }
    }
}
