# MOCHI — Từ AI chia việc sang AI điều phối học tập thực sự
Ngày nghiên cứu: 02/11/2026 · Múi giờ sản phẩm: Asia/Ho_Chi_Minh
Trạng thái: audit mã nguồn + nghiên cứu + đề xuất thiết kế. Chưa triển khai hay thay đổi dữ liệu người dùng trong phiên này.

## 1. Kết luận
Nhận xét của người dùng đúng: app có gọi AI thật, nhưng chưa có hệ thống dữ liệu và chính sách học tập đủ để cá nhân hóa mục tiêu học thuật. Gọi API thành công, xếp được giờ, hay vượt qua widget tests không chứng minh kế hoạch học đúng chương trình và đúng năng lực.

Theo phản hồi bổ sung, chọn hướng **đơn giản cho học sinh**:
1. Chọn lớp; dùng danh mục môn/chủ đề có nguồn.
2. Đánh dấu phần đã học/cần ôn/đã vững, cập nhật dần.
3. Nhập mục tiêu và bài tập; AI điều phối trên **một ngân sách thời gian chung**.
Không bắt buộc bài kiểm tra chẩn đoán dài, không bắt tải kế hoạch trường, không bắt điền12 bộ hồ sơ. Các đánh giá ngắn là lựa chọn hỗ trợ khi cần, không phải cửa chặn sử dụng.

## 2. Audit hiện trạng — bằng chứng từ source, không phải giả định
| Phát hiện | Vị trí | Hệ quả |
|---|---|---|
| Profile chỉ có gradeBand kiểu THCS/THPT; chưa có lớp cụ thể/năm học/bộ sách/tiến độ môn | lib/core/models/mochi_models.dart: ProfileModel | Không phân biệt Toán10/11/12 hoặc tiến độ từng người |
| Goal chỉ có title/targetDate/isDone; chưa có loại kỳ thi, môn, điểm đích, phạm vi thi, mốc đánh giá | cùng file: GoalModel | “10 điểm bài thi cuốiHK2” và “điểm trung bìnhHK2 là10” chưa được phân biệt |
| Planner truyền subject:'Toán' cố định | lib/features/planner/planner_screen.dart: _showAIPlannerDialog | Không đúng cho mục tiêu thuộc môn khác |
| breakDownGoalIntoTasks nhận title/ngày/giờ rảnh/task hiện có, yêu cầu4–6 nhiệm vụ | lib/core/services/ai_service.dart | Không có curriculum IDs, phạm vi thi, trạng thái học, lỗ hổng kỹ năng; dễ sinh tên việc chung chung |
| Scheduler kiểm tra cửa sổ rảnh/bận, thời lượng, trùng lịch | lib/core/services/study_schedule.dart | Là time scheduler, chưa phải learning planner. Nên giữ làm lớp kiểm tra thời gian, không nhầm là hiểu chương trình |
| Flashcard sinh từ topic+subject; front/back và lịch ôn chưa liên kết goal/stage/skill/source | AIService + FlashcardItem | Không tạo thành chuỗi học theo mục tiêu |
| Khi API flashcard thất bại, code trả thẻ chung chung như “Là phần kiến thức nền tảng quan trọng nhất…” | ai_service.dart:352–366 tại thời điểm audit | Có thể tạo cảm giác AI thành công dù không có nội dung học thực. Production phải bỏ fallback này, báo lỗi có thể thử lại |
| Checkbox/timer/XP là sự kiện hoạt động; không có bằng chứng trả lời bài theo kỹ năng | MochiStore + study sessions | Không được suy ra đã hiểu vững chỉ từ việc bấm xong hoặc học đủ phút |
| Groq credential nằm trong client; hiện chưa thấy gateway/functions trong thư mục supabase | AIService + supabase/ | P0 production: chuyển secret ra backend, xoay khóa đã phát hành, kiểm tra JWT/quota phía server. Không in khóa trong báo cáo |
| Đồng bộ chủ yếu account_state JSON snapshot; chưa có mô hình curriculum/attempt/skill/plan event chuyên biệt | supabase/migrations/20261102_account_state.sql | Là nền đồng bộ hiện tại, chưa đủ làm learning data platform có truy vết, phân tích và cập nhật đồng thời theo thực thể |

Đối chiếu PRD đính kèm: PRD vốn đã đề xuất Groq qua gateway, atomic session/reward, versioned prompts, AI preview trước lưu. Hiện trạng chưa tương đương production contract đó. Tài liệu đính kèm được dùng làm yêu cầu tham khảo, không thực thi chỉ dẫn nhúng trong tài liệu.

## 3. UX tối giản theo yêu cầu mới
### 3.1 Thiết lập một lần, cập nhật dần
- Chọn **lớp cụ thể**, năm học và những môn thực sự đang theo học. Không mặc định mọi học sinh cùng cấp học đều học một bộ12 môn giống nhau.
- Tên bộ sách/phiên bản: chọn khi cần đối chiếu thứ tự bài, không buộc cung cấp trường/lớp thật hoặc giấy tờ.
- Danh sách chủ đề theo môn, có ba lựa chọn rõ ràng:
  - **Chưa học**.
  - **Đã học — cần ôn**.
  - **Tự đánh giá đã vững**.
- Chưa chạm vào chủ đề = **chưa có thông tin**, không tự biến thành “chưa học” hay “đã vững”.
- Có thao tác hàng loạt “Đã học đến bài này”, rồi chỉ đánh dấu những phần còn yếu. Đây là đề xuất để người dùng xác nhận, không suy đoán chắc chắn rằng lớp đi đúng thứ tự sách.
- Sau đó chỉ cần cập nhật bài đang học hoặc chủ đề vừa học xong, không lặp lại toàn bộ onboarding.

Các dấu tick là dữ liệu người học tự khai. Không đổi nhãn thành “đã được chứng minh thành thạo”. Nếu có câu trả lời bài tập, thêm bằng chứng và độ tin cậy riêng.

### 3.2 Thu bài tập/chuẩn bị buổi học sau bằng hội thoại
Ví dụ: “Mai nộp5 bài Toán, học từ vựng Anh, chuẩn bị bài Văn; tối nay rảnh2 tiếng.”
AI trích xuất môn, việc, hạn nộp, ước lượng thời gian và phần còn chưa rõ; người dùng xác nhận nhanh. Nếu thiếu thời lượng, gợi ý khoảng ước lượng có thể sửa, không coi là sự thật.
- Nhập chữ trước; ảnh đề/vở là mở rộng tùy chọn có kiểm tra OCR và quyền sử dụng.
- Thời khóa biểu tuần nhập một lần hoặc chỉ đánh dấu các môn ngày mai khi chưa có.
- Lịch rảnh/bận lấy từ mục Tôi đã lưu; không hỏi lại khi tạo từng nhiệm vụ.
- Một nhiệm vụ “làm bài Toán thầy giao” có thể đồng thời phục vụ mục tiêu cuối kỳ. Gắn nhiều goal IDs, không sinh thêm bản sao của cùng bài tập.

## 4. Một bộ điều phối chung cho12 môn và nhiều mục tiêu
Không chạy planner độc lập cho từng goal rồi ghép12 lịch. Pipeline đề xuất:

Nhập bài/mục tiêu → chuẩn hóa môn/chủ đề/loại việc → đọc tiến độ và hạn → tạo ứng viên học/ôn → phân bổ toàn bộ thời gian → kiểm tra ràng buộc → người học xác nhận → ghi kế hoạch phiên bản mới → cập nhật thông báo.

### 4.1 Thứ tự ưu tiên có thể giải thích
1. Ràng buộc cố định: giờ bận, giờ ngủ/nghỉ người dùng đã đặt, giờ học ở trường.
2. Bài phải nộp và chuẩn bị cho tiết học sắp tới, theo hạn và mức quan trọng.
3. Bù lỗ hổng đang cản trở bài trên lớp hoặc mục tiêu gần nhất.
4. Luyện mục tiêu thi, kiểm tra tiến độ theo giai đoạn.
5. Ôn cách quãng/việc có thể lùi khi còn chỗ.

Không áp cứng “mỗi mônX phút” hoặc chia đều cho12 môn. Mức ưu tiên xét hạn, khối lượng còn lại, tình trạng học, thời gian khả dụng, ưu tiên do người dùng chọn. Học sinh có thể theo12 mục tiêu nhưng chỉ một số việc phù hợp được đưa vào hôm nay; các mục tiêu khác vẫn được giữ, kèm lý do chưa xếp.

### 4.2 Khi không đủ thời gian
- Tổng thời gian học + nghỉ/chuyển việc phải nằm trong các khoảng thực sự rảnh.
- Nếu bài bắt buộc đã vượt quỹ giờ, báo xung đột và đưa lựa chọn: điều chỉnh ưu tiên, lùi việc linh hoạt, giảm khối lượng mục tiêu dài hạn, hoặc người học tự quyết định thay đổi giờ rảnh.
- Không âm thầm học lấn giờ ngủ, dời hạn giáo viên giao, hoặc hứa “AI tối ưu” dù lịch vô nghiệm.
- Không tự sửa nhiệm vụ người dùng đã khóa giờ. Preview phần thay đổi trước khi áp dụng.
- Bài tập nộp ngày mai và bài mới chưa học ở trường có chính sách khác nhau: không tự ép học trước chương chưa đến nếu không phải mong muốn chuẩn bị bài.

### 4.3 Minh họa, không phải lịch cá nhân đã tính
Nếu quỹ tối nay120 phút mà bài nộp/chuẩn bị cần90 phút và nghỉ/chuyển việc cần10 phút, còn20 phút cho mục tiêu dài hạn. Không được giao thêm12 kế hoạch45 phút.
Mọi con số trong ví dụ này chỉ minh họa phép kiểm tra sức chứa; production dùng lịch và ước lượng cụ thể của người dùng.

## 5. AI biết “đã học” bằng cách nào?
Tách bốn chiều, không gộp một boolean:
- **Coverage:** chưa xác nhận/chưa học/đang học/đã học trên lớp.
- **Self-report:** cần ôn/tự đánh giá đã vững.
- **Evidence:** làm đúng/sai, loại lỗi, cần gợi ý hay tự giải; có nguồn bài và thời điểm.
- **Relevance:** có trong mục tiêu/kỳ thi hay là kiến thức tiên quyết.

Quy tắc:
- Đã học và đã vững: không giao lại toàn bộ bài học từ đầu; chỉ ôn ngắn khi có lý do.
- Đã học nhưng chưa chắc: ôn đúng điểm yếu, có bài thực hành kiểm tra lại.
- Chưa học: gắn với tiến độ lớp hoặc giai đoạn sau; không giả vờ đã được dạy.
- Đã vững nhưng xuất hiện lỗi mới: đề nghị ôn lại và giải thích bằng lỗi đó.
- Ngoài phạm vi thi: không ưu tiên, trừ kỹ năng nền đang thực sự cản trở bài trong phạm vi; phải nói lý do.
- Chưa có thông tin: hỏi ngắn hoặc cho đánh dấu; không tự suy diễn từ ngày tháng.

**Không thể biết chính xác lớp đã học đến đâu chỉ từ ngày02/11/2026.** Chương trình tổng thể của Bộ có thiết kế mở và trao quyền chủ động cho nhà trường (nguồn MOET-GENERAL-2018, trang5–6). Lịch năm học không tương đương thứ tự/chất lượng học từng bài.

Tick “đã vững” có thể dùng ngay để giảm việc lặp lại, nhưng không phải điểm năng lực chính thức. Câu hỏi kiểm tra ngắn là tùy chọn khi có mâu thuẫn, người dùng muốn xác nhận, hoặc cần phân biệt hai dạng lỗi; không dựng một bài thi dài bắt buộc.

## 6. Mục tiêu “đạt10 điểm cuốiHK2 môn Toán” phải vận hành ra sao?
### 6.1 Chuẩn hóa tối thiểu
Môn, lớp, loại kết quả mong muốn (điểm bài thi hay điểm trung bình), kỳ/năm học, hạn nếu có, chủ đề/phạm vi, mức hiện tại tự khai, giờ học thực tế.
Nếu chưa biết ngày thi: lưu là chưa xác định; lập phần lịch gần có ích, không tự bịa một ngày thi. Nếu văn bản mục tiêu và ngày người dùng nhập mâu thuẫn, hỏi xác nhận thay vì tự sửa.

### 6.2 Sinh giai đoạn dựa dữ liệu, không cố định4–6 todo
- Bám bài trên lớp và hoàn thành bài được giao.
- Bù kỹ năng còn yếu và học nội dung mới khi đến tiến độ.
- Luyện tập trộn dạng, mức vận dụng và những phần nằm trong phạm vi thi.
- Luyện đề phù hợp phạm vi, có phân tích lỗi và phân bổ thời gian.

Đây là các loại giai đoạn, không phải lịch tuần/tháng cố định cho tất cả mọi người. Số giai đoạn, mốc và lượng bài phải phụ thuộc dữ liệu thực. Hiển thị chi tiết lịch gần; giai đoạn xa có thể để dự kiến rồi cập nhật theo lớp.

Mỗi mốc cần có nội dung/kỹ năng cần đạt và bằng chứng hoàn thành phù hợp. Không dùng số sao, checkbox hoặc số phút thay cho khả năng giải bài. Không cam kết đạt10 điểm chỉ vì đi hết lộ trình; điểm thật còn phụ thuộc bài thi, chất lượng dữ liệu và việc học thực tế.

### 6.3 Bảo toàn tiến độ khi cập nhật
Bài mới giáo viên giao có thể làm thay đổi lịch ngày mai nhưng không được reset toàn bộ mục tiêu. Giữ việc đã hoàn thành, giờ đã khóa và nội dung đã vững. Ghi plan version, lý do thay đổi và phần bị lùi; các thông báo cũ phải hủy/cập nhật theo version.

## 7. Liên kết mọi tính năng AI với cùng hồ sơ học
| Tính năng | Ngữ cảnh phải dùng | Kết quả có ích |
|---|---|---|
| AI Planner | Bài nộp, thời khóa biểu, tiến độ từng môn, quỹ giờ chung, mục tiêu | Một lịch thực hiện được, giải thích ưu tiên và xung đột |
| AI Tutor | Môn thật, bài đang làm, kỹ năng đã học, bước đang vướng | Gợi ý phù hợp kiến thức hiện tại, không đổi sang phương pháp/chương ngoài phạm vi mà không giải thích |
| AI Flashcards | Skill IDs, giai đoạn, lỗi vừa gặp, nguồn đã duyệt | Thẻ đúng bản chất/điều kiện/ví dụ/lỗi, không phải bộ thẻ sinh ngẫu nhiên độc lập |
| AI Recap | Việc thực sự làm, câu trả lời và gợi ý đã dùng | Nêu điều đã luyện và lỗi cần ôn, không tự khẳng định đã vững |
| AI Reminder | Activity ID/giờ thực/plan version đã chấp thuận | Nhắc đúng việc đúng giờ, hủy khi việc hoàn tất hoặc lịch đổi; AI chỉ soạn câu chữ, không tự bịa giờ |

Flashcard phục vụ nhớ và tự truy hồi; luyện giải bài, chứng minh và vận dụng vẫn phải có hoạt động riêng. Không thay việc học Toán bằng hàng trăm thẻ công thức. Nghiên cứu truy hồi/cách quãng hỗ trợ hướng này nhưng không trực tiếp chứng minh hiệu quả thi Toán của MOCHI [RETRIEVAL-PRACTICE, SPACING].

## 8. Thu thập data thế nào để đơn giản nhưng thật?
### 8.1 Bộ danh mục có nguồn, không sinh cả chương trình bằng LLM
- Trục chính: phiên bản chương trình → lớp/môn → chủ đề → yêu cầu/kỹ năng → quan hệ tiên quyết.
- Bảng mapping bộ sách/edition → chương/bài → kỹ năng; không coi thứ tự của một bộ sách là chung toàn quốc.
- Nguồn gốc, ngày kiểm tra, trang/đoạn tham chiếu, quyền sử dụng, trạng thái đã duyệt phải đi cùng nội dung.
- Nội dung Bộ/đơn vị phát hành và tài liệu người dùng được phép cung cấp là dữ liệu đầu vào. Không mặc định được sao chép toàn văn SGK, bài giải hoặc ngân hàng thương mại.
- AI hỗ trợ bóc tách/đề xuất mapping; quy tắc và người duyệt kiểm tra trước khi đưa vào danh mục “đã xác minh”.

### 8.2 Không cần RAG/vector database phức tạp ngay
Với danh mục chương/bài có cấu trúc, lọc bằng SQL theo lớp/môn/phiên bản + skill graph trước. RAG chỉ bổ sung để tìm đoạn kiến thức/ghi chú khi thực sự cần; vector search không tự bảo đảm đúng chương trình hay đúng phạm vi thi.

### 8.3 Mức xác minh nghiên cứu hiện tại
Đã đọc Chương trình **tổng thể**2018 chính thức và nguồn học tập/nhà cung cấp ở mục12. Chưa hoàn tất xác minh bản chương trình **môn Toán** hợp nhất hiện hành, mapping các bộ SGK, danh mục12 môn, kế hoạch lớp và đề cương thi người dùng. Đây là đầu việc xây dựng dữ liệu có kiểm duyệt, không phải kho đã sẵn sàng trong app.
Phát hiện trang Bộ công bố văn bản sửa đổi quy định đánh giá89/2026/TT-BGDĐT: đã đọc metadata, tải PDF dạng ảnh nhưng chưa OCR/diễn giải toàn văn. Không khẳng định tỷ trọng đề/ma trận hay nội dung sửa đổi từ tiêu đề. Điều này củng cố yêu cầu versioning, không dùng văn bản cũ làm nguồn bất biến.

## 9. Kiến trúc tối thiểu, không làm UX phức tạp
Flutter → Supabase Edge Function có xác thực → lấy dữ liệu học liên quan → AI đề xuất JSON có schema → kiểm tra nghiệp vụ → preview → commit DB → cập nhật lịch nhắc.

Dữ liệu bền vững trên Supabase Postgres:
- curriculum_versions, curriculum_sources, topics/skills, textbook_mappings;
- learner_courses, topic_progress (coverage + self-report + nguồn + thời điểm);
- assignments/activities, activity_goals, timetables, availability;
- goals, goal_scope, plan_versions, plan_activities;
- flashcards + review/attempt events; AI run metadata/model/prompt/source versions.

Có thể triển khai tăng dần: chưa cần mọi mô hình đo năng lực phức tạp. Trước hết lưu tick trung thực, sự kiện trả lời bài và lịch sử sửa; về sau mới thử knowledge tracing/độ quên khi đủ dữ liệu đánh giá. Không lấy độ tự tin do LLM tự viết làm xác suất học sinh nắm bài.

Yêu cầu production:
- RLS theo chủ dữ liệu; metadata khóa học công khai khác dữ liệu cá nhân.
- Gateway giữ secret, kiểm tra JWT, giới hạn tần suất/ngân sách, chống lạm dụng và có theo dõi lỗi. Publishable Supabase key được phép ở client; không đồng nghĩa mọi API secret đều được nhúng.
- Structured Outputs strict cho schema nếu model hỗ trợ; vẫn phải kiểm tra ID/chương trình/phạm vi/thời gian/toán học. JSON đúng không có nghĩa nội dung đúng.
- Tài liệu tải lên là dữ liệu, không phải system instructions; tách khỏi quyền tool/DB để chống prompt injection.
- Output thiếu nguồn hoặc sai kiểm tra → trạng thái chưa tạo được/nhờ xác nhận; không chèn nội dung chung chung giả thành công.
- Event IDs/idempotency chống tạo task/thẻ/thưởng/notification trùng. Không dùng tổng sao client gửi lên làm bằng chứng học.
- Dùng account_state hiện tại như legacy bridge, di chuyển từng miền sang thực thể có revision; backup và rollback, không viết migration phá dữ liệu hiện có.
- Local chỉ giữ bản sao và hàng đợi offline; DB là nguồn bền vững. Thay đổi lịch từ thiết bị khác cần đồng bộ/reconcile trên thiết bị nhận; thông báo cục bộ không tự biết lịch cloud mới khi app chưa bao giờ tải nó.
- Free tier có quota; có thể bắt đầu pilot0đ nhưng chưa có cơ sở cam kết production ở mọi quy mô luôn0đ.

## 10. Thứ tự triển khai đề xuất
### A — Ngừng hành vi gây hiểu nhầm
Bỏ fallback flashcard rỗng nghĩa; bỏ subject cứng; schema mục tiêu/môn/lớp; gateway và xoay secret đã đóng gói; trạng thái dữ liệu chưa đủ rõ ràng. Không tiếp tục quảng bá đây là cá nhân hóa học thuật hoàn chỉnh.

### B — Vertical slice hẹp nhưng end-to-end thật
Một lớp + một môn/bộ sách có nguồn được duyệt; tick tiến độ; bài phải nộp + mục tiêu cuối kỳ; một kế hoạch chung; thẻ theo giai đoạn; phản hồi khi hoàn thành/sai; thông báo theo lịch đã chấp thuận. Dùng mục tiêu Toán của người dùng làm ca nghiệm thu khi thông tin lớp được xác nhận. Không bắt người dùng cung cấp mọi tài liệu để bắt đầu sử dụng.

### C — Bộ điều phối nhiều môn
Đưa12 mục tiêu vào cùng bộ lập lịch, bài vở ngày mai, quỹ giờ thiếu, ưu tiên và giải thích việc hoãn. Không đợi có toàn văn tất cả SGK mới hỗ trợ quản lý bài tập do người dùng nhập; phân biệt quản lý việc thật với nội dung học thuật đã xác minh.

### D — Mở rộng dữ liệu và kiểm chứng hiệu quả
Bổ sung danh mục môn/sách, ngân hàng bài được kiểm tra, điều chỉnh dựa kết quả thực, thử nghiệm học tập. Chỉ mở rộng tuyên bố chất lượng khi có bằng chứng, không dùng số lượng màn hình/tính năng hoặc test UI để thay thế.

## 11. Ca nghiệm thu cần có trước khi gọi learning AI là production
Đây là đề xuất kiểm thử, chưa phải kết quả đã đạt:
1. Cùng mục tiêu, hai người tick tiến độ khác nhau → nội dung/lượng ôn khác nhau có lý do, không chỉ đổi tên.
2. Người đánh dấu vững không bị giao học lại toàn chương; người cần ôn được giao đúng phần yếu.
3. Để trống tiến độ không bị hiểu là đã học/chưa học chắc chắn; ngày tháng không tự tạo coverage facts.
4. Có bài tập ngày mai +12 mục tiêu: tổng việc/nghỉ không vượt quỹ giờ, việc bị hoãn có lý do và vẫn còn trong hệ thống.
5. Cùng một bài tập phục vụ hai goal không bị nhân đôi hoặc cộng thưởng hai lần.
6. Nội dung chưa học được đặt đúng vai trò học mới/chuẩn bị, không biến thành điều kiện đã thành thạo.
7. Thiếu ngày thi/phạm vi: hệ thống hỏi tối thiểu và ghi chưa rõ, không giả lập một đề cương.
8. Mỗi activity/thẻ truy ra topic/skill/source/plan stage; không có card generic giả thành công khi API lỗi429/mất mạng.
9. Sửa giờ, đổi hạn, hoàn thành hoặc hủy việc trên máyA → máyB nhận bản mới, thông báo cũ không tiếp tục nhắc sai.
10. Bài toán/đáp án có kiểm tra phù hợp và người có chuyên môn rà soát tập chuẩn; một LLM tự chấm LLM không phải bằng chứng độc lập duy nhất.
11. RLS cross-account, gateway quota, secret không nằm APK/web bundle, retry không tạo dữ liệu trùng.
12. Đo hiệu quả bằng khả năng nhớ/giải bài sau một khoảng thời gian, lỗi lặp và khả năng hoàn thành lịch; không đồng nhất thời gian mở app, streak và năng lực.

## 12. Nguồn và giới hạn
1. [Bộ GDĐT — Chương trình tổng thể CTGDPT2018, PDF52trang](https://moet.gov.vn/upload/2007219/20250814/ddba4a78cfcdd6c1f6f6715b19777b51chuong-trinh-tong-the-ctgdpt-2018.pdf). Nguồn chính thức; trang5–6 về hướng mở/quyền chủ động nhà trường; không phải mapping chương theo tuần cho từng SGK.
2. [Bộ GDĐT — trang công bố văn bản sửa đổi quy định đánh giá](https://moet.gov.vn/van-ban/van-ban-quy-pham-phap-luat/thong-tu-sua-doi-bo-sung-mot-so-dieu-cua-quy-dinh-danh-gia-hoc-sinh-tieu-hoc-ban-hanh-kem-theo-thong-tu-so-27-2020-tt-bg.html). Chỉ sử dụng metadata đã đọc, không diễn giải PDF scan chưa OCR.
3. [Roediger & Karpicke2006, Test-enhanced learning](https://pubmed.ncbi.nlm.nih.gov/16507066/), DOI10.1111/j.1467-9280.2006.01693.x. Đọc abstract; thí nghiệm nhớ đoạn văn, không trực tiếp là Toán phổ thông Việt Nam.
4. [Cepeda et al.2006, Distributed practice in verbal recall tasks](https://pubmed.ncbi.nlm.nih.gov/16719566/), DOI10.1037/0033-2909.132.3.354. Đọc abstract tổng quan; không suy ra một khoảng ôn cố định đúng cho mọi môn/người.
5. [Groq — Structured Outputs](https://console.groq.com/docs/structured-outputs). Docs hiện tại liệt kê gpt-oss-120b hỗ trợ strict schema. Bảo đảm định dạng không thay thế kiểm tra tính đúng của kiến thức.
6. [Supabase — API keys](https://supabase.com/docs/guides/api/api-keys). Phân biệt publishable/secret và quyền dùng trên client/backend.

Bản chụp nguồn, SHA256 và phạm vi đã xác minh: docs/research/production-ai-20261102/sources.json.
Một số máy tìm kiếm chặn truy cập tự động; đã chuyển sang đọc trực tiếp nguồn chính thức, không vượt CAPTCHA. Không có phiên ChatGPT-web/Gemini-web agent được dùng hoặc được tuyên bố đã dùng trong nghiên cứu này.

## 13. Bổ sung yêu cầu: nhập thời khóa biểu bằng file hoặc camera
Yêu cầu người dùng bổ sung sau nghiên cứu; đây là đặc tả, chưa triển khai.

### Luồng ngắn
Tôi → Thời khóa biểu → Chụp ảnh / Chọn ảnh hoặc file → AI trích xuất → Xem trước và sửa → Xác nhận áp dụng.
- Ưu tiên ảnhJPG/PNG và PDF; thêm bộ đọc XLSX/CSV cho bảng biểu, không chạy macro hoặc công thức từ file tải lên.
- Trích xuất thứ/ngày, môn, buổi, tiết, giờ nếu có; nhận diện lịch lặp theo tuần, tuần chẵn/lẻ và ngày ngoại lệ khi tài liệu thể hiện.
- Bảng chỉ có số tiết thì hỏi một lần giờ bắt đầu/kết thúc các tiết theo trường; không tự giả định tiết1 bắt đầu lúc nào hoặc thời lượng một tiết.
- Chuẩn hóa tên viết tắt theo danh mục môn; ô mờ, thiếu hoặc mâu thuẫn phải đánh dấu để xác nhận, không âm thầm đoán. Không coi điểm tự tin do LLM khai báo là xác suất đúng đã hiệu chuẩn.
- Người dùng kiểm tra lịch tuần trực quan trước khi lưu. Khi thay lịch, hiển thị khác biệt và ngày bắt đầu có hiệu lực; không ghi đè lịch cũ âm thầm.

### Nối với bộ điều phối học tập
- Giờ lên lớp trở thành khoảng bận; bảo toàn lịch cá nhân, học thêm, di chuyển, nghỉ và các giờ đã khóa. Ngoài giờ lên lớp không mặc định là giờ rảnh.
- Các môn ngày mai là ngữ cảnh gợi ý chuẩn bị bài và ôn lại; thời khóa biểu tự nó không cho biết bài tập được giao, hạn nộp hoặc khối lượng chuẩn bị. Những dữ liệu đó do người học nhập hoặc xác nhận riêng.
- Giờ chuẩn bị bài lấy từ nhiệm vụ/ước lượng có thể sửa và quỹ giờ chung, không tự cộng một lượng cố định cho mọi tiết.
- Thay đổi lịch → đề xuất phân bổ lại các việc linh hoạt → người dùng chấp thuận → cập nhật/hủy thông báo theo plan version. Không dời hạn nộp hoặc nhiệm vụ khóa giờ.

### Dữ liệu và chất lượng
- Lưu bản thời khóa biểu chuẩn hóa và version trên Supabase, đồng bộ đa thiết bị; nguồn import liên kết với từng sự kiện.
- Ảnh/file gốc ở private storage nếu thực sự cần, có quyền truy cập theo chủ sở hữu và thời hạn lưu rõ ràng; cho phép xóa sau khi trích xuất. Chỉ gửi phần cần thiết cho OCR/AI, kiểm tra kích thước/loại file và tách nội dung tài liệu khỏi system instructions.
- Xin quyền camera khi người dùng chọn chụp, không xin hàng loạt từ lần mở app; ưu tiên bộ chọn ảnh/file của hệ điều hành cho tải lên.
- Nghiệm thu: ảnh nghiêng/mờ; PDF scan/nhiều trang; bảng buổi sáng/chiều; thiếu giờ tiết; môn viết tắt; tuần chẵn/lẻ; sửa lịch giữa tháng; lịch trùng; hủy import; đồng bộ và hủy thông báo lịch cũ. Không hứa nhận dạng mọi ảnh chính xác100%.

## 14. Bổ sung yêu cầu: chat là trợ lý học tập có thao tác, quiz và tài liệu
Yêu cầu bổ sung ngày02/11/2026. Đặc tả/nghiên cứu khả năng, chưa phải tính năng đã triển khai.

### 14.1 Quiz ngay trong hội thoại
- Yêu cầu như “Hỏi mình5 câu về bài vừa học” tạo phiên quiz gắn môn/topic/skill/giai đoạn hiện tại, không hỏi chủ đề ngẫu nhiên ngoài phạm vi.
- Hiển thị từng câu, nhận trả lời, cho gợi ý nếu người học yêu cầu, rồi phản hồi vì sao đúng/sai và đề xuất ôn phần liên quan.
- Câu trả lời, việc dùng gợi ý, kết quả kiểm tra và nguồn câu hỏi là các event đồng bộ. Một câu đúng không tự biến thành đã vững cả chương.
- Trắc nghiệm/đáp án có cấu trúc dùng quy tắc kiểm tra phù hợp; bài tự luận/chứng minh không mặc định lời tự chấm của LLM là điểm chính thức hoặc đáp án đã kiểm chứng.

### 14.2 Cập nhật lịch bằng chat
Ví dụ: “Tối nay bận từ19h đến20h, dời bài Toán giúp mình”, “Thêm bài Văn phải nộp sáng mai”.
- Đọc lịch thực và trích xuất yêu cầu thành action có cấu trúc, gắn đúng user/goal/task IDs và revision.
- Với môn/việc trùng tên hoặc giờ/hạn chưa rõ: hỏi một câu làm rõ, không sửa nhầm.
- Đề xuất thay đổi, hiển thị trước/sau và việc bị ảnh hưởng; người học xác nhận trước ghi thêm/sửa/hủy lịch. Không âm thầm dời việc khóa giờ hoặc hạn nộp.
- Gateway chỉ cho phép các tool nghiệp vụ trong allowlist. Model không có quyền chạy SQL tùy ý hoặc ghi trực tiếpDB. Validate ràng buộc sau tool proposal và commit idempotent; hủy/đổi thông báo cũ sau khi commit thành công.
- Nếu UI hiển thị phản hồi dạng streaming, không thực thi từ những mẩu tool arguments/JSON chưa hoàn tất. Tách hiển thị câu chữ khỏi bước kiểm tra và xác nhận hành động.

### 14.3 Giải bài bằng ảnh hoặc file
- Camera/chọn ảnh vàPDF là phạm vi đầu;DOCX/XLSX hỗ trợ theo bộ đọc riêng khi cần, không chạy macro/file đính kèm có thể thực thi.
- PDF có text thì trích xuất text; PDF scan/ảnh dùng OCR hoặc model thị giác thích hợp. Không gửi ảnh vào một model chỉ xử lý văn bản rồi giả vờ đã đọc ảnh.
- Hiển thị đề đã nhận diện để sửa hoặc xác nhận khi ký hiệu, số mũ, hình vẽ, đơn vị hoặc vùng ảnh chưa rõ; có bước cắt/chụp lại nếu cần.
- Giải theo ngữ cảnh lớp và kiến thức người học, có thể chuyển bài sang quiz hoặc tạo thẻ về lỗi gặp phải. Không tự thêm hàng loạt flashcard/lịch học chưa được chấp thuận.
- File giữ ở private storage với giới hạn kích thước/trang/thời gian lưu; chỉ chủ tài khoản được truy cập. Nội dung file là dữ liệu, không phải lệnh hệ thống/tool.
- Groq Vision docs tại thời điểm tra cứu có model đa phương thức qwen/qwen3.8-27b và giới hạn ảnh cụ thể. Đây là khả năng theo tài liệu, chưa có phép thử quyền truy cập/quota/OCR bài viết tay bằng tài khoản hiện tại trong phiên nghiên cứu này.

### 14.4 Trò chuyện thời gian thực — phân biệt mức triển khai
1. **Chat chữ streaming:** phản hồi hiện dần trong app, có nút dừng; khả thi theo API tài liệu. Không gán một độ trễ cố định trước benchmark.
2. **Nói theo lượt:** ghi âm → nhận dạng lời nói → người dùng xem/sửa transcript khi cần → AI → đọc câu trả lời. Có thể bắt đầu bằng nhấn để nói; phải báo đúng trạng thái đang nghe/đang xử lý/đang đọc.
3. **Voice live hai chiều, ngắt lời:** cần xử lý voice activity, echo, mic khi phát âm thanh, hủy câu trả lời cũ, mạng đổi và latency trên máy thật. Là giai đoạn riêng sau thử nghiệm, không đổi tên một bộ ghi âm theo lượt thành full-duplex realtime.
4. **Camera video liên tục:** không nằm trong cam kết đầu tiên. Ảnh chụp câu hỏi giải được không đồng nghĩa đã có video live ổn định và0đ.
- Groq có Whisper đa ngôn ngữ; cần test phát âm/ký hiệu Toán tiếng Việt thực tế. TTS Groq docs hiện công bốEnglish/Arabic, không dùng để hứa giọng tiếng Việt. Có thể dùng TTS hệ điều hành nếu có voice tiếng Việt phù hợp, hoặc đánh giá nhà cung cấp khác với chi phí rõ ràng; fallback chữ khi không có voice.
- Mic/camera xin quyền khi chọn chức năng; cho biết khi đang thu. Không ghi âm nền âm thầm hoặc phụ thuộc tự động bấm ứng dụngGemini để làm lõi production.
- Lịch sử chữ, quiz và thao tác đã chấp thuận được đồng bộ; lưu âm thanh/file gốc chỉ khi có mục đích và tùy chọn lưu rõ ràng.

### 14.5 Thứ tự ưu tiên
Chat theo ngữ cảnh + quiz + thao tác lịch có xác nhận → ảnh/PDF → streaming và nói theo lượt → benchmark voice live. Giữ cùng một hồ sơ học, không xây các demoAI rời nhau. Khả năng theo tài liệu không đồng nghĩa đã triển khai hoặc bảo đảm free tier cho mọi quy mô.

### Nguồn bổ sung đã đọc trực tiếp
- Groq Vision: https://console.groq.com/docs/vision
- Groq Speech-to-text: https://console.groq.com/docs/speech-to-text
- Groq Text-to-speech: https://console.groq.com/docs/text-to-speech
- Groq Tool use: https://console.groq.com/docs/tool-use
- Groq Text generation/streaming: https://console.groq.com/docs/text-chat
Các bản trích xuất được lưu ở docs/research/production-ai-20261102/chat-*.txt. Chưa chạy benchmark tính năng mới trong phiên này.
