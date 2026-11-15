import "dart:convert";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";
import "package:mochi_app/core/services/ai_service.dart";

void main() {
  group("Vision Features Acceptance", () {
    test("extractTimetable with imageDataUri parses lesson array", () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), contains("chat/completions"));
        final body = jsonDecode(request.body);
        expect(body["model"], "qwen/qwen3.8-27b");
        expect(body["messages"][1]["content"][1]["type"], "image_url");
        final respJson = jsonEncode({
          "choices": [
            {
              "message": {
                "content": jsonEncode([
                  {
                    "subject": "Toán",
                    "weekday": 2,
                    "startTime": "07:15",
                    "endTime": "08:45",
                  },
                  {
                    "subject": "Vật lý",
                    "weekday": 4,
                    "startTime": "09:05",
                    "endTime": "10:35",
                  }
                ])
              }
            }
          ]
        });
        return http.Response.bytes(
          utf8.encode(respJson),
          200,
          headers: {"content-type": "application/json; charset=utf-8"},
        );
      });

      final service = AIService(client: mockClient);
      final lessons = await service.extractTimetable(
        imageDataUri: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=",
      );

      expect(lessons.length, 2);
      expect(lessons[0]["subject"], "Toán");
      expect(lessons[0]["weekday"], 2);
      expect(lessons[0]["startTime"], "07:15");
      expect(lessons[1]["subject"], "Vật lý");
      expect(lessons[1]["weekday"], 4);
    });

    test("solveProblemWithImage passes vision payload and returns pedagogical solution", () async {
      final mockClient = MockClient((request) async {
        final body = jsonDecode(request.body);
        expect(body["model"], "qwen/qwen3.8-27b");
        expect(body["messages"][1]["content"][0]["text"], contains("2x + 3 = 7"));
        expect(body["messages"][1]["content"][1]["type"], "image_url");
        final respJson = jsonEncode({
          "choices": [
            {
              "message": {
                "content": "Buoc 1: Tru 3 o hai ve. 2x = 4. Buoc 2: Chia cho 2. x = 2."
              }
            }
          ],
          "model": "qwen/qwen3.8-27b",
          "id": "test-vision-123"
        });
        return http.Response.bytes(
          utf8.encode(respJson),
          200,
          headers: {"content-type": "application/json; charset=utf-8"},
        );
      });

      final service = AIService(client: mockClient);
      final res = await service.solveProblemWithImage(
        imageDataUri: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=",
        userQuestion: "Giai giup minh phuong trinh 2x + 3 = 7 trong anh",
        subject: "Toán",
        gradeBand: "THPT · Lớp 11",
      );

      expect(res["source"], "groq_cloud");
      expect(res["reply"], contains("x = 2"));
      expect(res["requestId"], "test-vision-123");
    });
  });
}
