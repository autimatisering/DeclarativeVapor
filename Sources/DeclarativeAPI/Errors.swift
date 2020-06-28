enum CustomRouterError: Error {
    case pathComponentDecodeFailure(input: String, output: Any.Type)
    case invalidHttpMethod(provided: String, needed: String)
    case unexpectedBodyProvided
    case missingBody
    case missingPathComponent(Any.Type)
    case missingRequest
}
