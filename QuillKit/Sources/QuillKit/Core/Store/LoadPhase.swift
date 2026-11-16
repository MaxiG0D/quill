enum LoadPhase: Equatable, Sendable {
    case idle, loading, loaded
    case failed(String)
}
