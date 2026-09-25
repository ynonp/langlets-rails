import XCTest
@testable import LangletsNativeCore

final class NativeCoreTests: XCTestCase {
    func testSnakeCaseContractAndUnknownFields() throws {
        let json = #"{"id":8,"name":"Lesson","course_slug":"example","language":"es","schema_version":1,"downloaded_at":"2026-09-25T00:00:00Z","offline_until":"2099-01-01T00:00:00Z","activities":[{"id":9,"kind":"FlashcardActivity","phrase_ids":[1],"token_ids":[2]}],"phrases":[],"completed_activity_ids":[],"future_field":true}"#
        let lesson = try JSONDecoder.native.decode(NativeLesson.self, from: Data(json.utf8))
        XCTAssertEqual(lesson.courseSlug, "example")
        XCTAssertEqual(lesson.activities.first?.tokenIds, [2])
        XCTAssertTrue(lesson.availableOffline)
    }
    func testOutboxSurvivesSerializationWithBooleanTypesAndStableIdentity() throws {
        let operation = NativeMutation(id: UUID(), payload: ["kind": .string("word_update"), "entry_id": .integer(5), "practicing": .bool(false)])
        var state = NativeSnapshot(); state.outbox = [operation]; state.completedLessons.insert(32)
        let restored = try JSONDecoder.native.decode(NativeSnapshot.self, from: JSONEncoder.native.encode(state))
        XCTAssertEqual(restored.outbox.first?.id, operation.id)
        XCTAssertEqual(restored.outbox.first?.payload, operation.payload)
        XCTAssertEqual(restored.completedLessons, [32])
    }
    func testClozeUsesUnicodeScalarOffsetsAndOnlySelectedOccurrence() {
        let token = NativeToken(id: 1, text: "你", translation: "you", startIndex: 4, endIndex: 4, start: nil, end: nil, questions: [], similarSounds: [], audio: nil)
        let phrase = NativePhrase(id: 1, text: "你 😀 你", translation: "", language: "zh", rtl: false, start: nil, provider: nil, videoId: nil, audio: nil, tokens: [token])
        XCTAssertEqual(phrase.cloze(token), "你 😀  _____ ")
    }
    func testExpiredLeaseIsNotAvailableOffline() throws {
        let json = #"{"id":1,"schema_version":1,"downloaded_at":"2000-01-01T00:00:00Z","offline_until":"2000-01-08T00:00:00Z","activities":[],"phrases":[],"completed_activity_ids":[]}"#
        let lesson = try JSONDecoder.native.decode(NativeLesson.self, from: Data(json.utf8))
        XCTAssertFalse(lesson.availableOffline)
    }
}
