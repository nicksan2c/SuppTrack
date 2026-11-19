/// Adult age band used to pick upper limits (calcium differs at 51+).
public enum AgeGroup: String, Codable, CaseIterable, Sendable {
    case adult19to50
    case adult51plus
}
