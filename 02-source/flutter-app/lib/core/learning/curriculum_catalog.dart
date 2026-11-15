import 'learning_models.dart';

/// Subject choices, not a claim that every student takes every listed course.
const learningSubjectChoices = [
  'Toán',
  'Ngữ văn',
  'Tiếng Anh',
  'Vật lý',
  'Hóa học',
  'Sinh học',
  'Lịch sử',
  'Địa lý',
  'Giáo dục kinh tế và pháp luật',
  'Tin học',
  'Công nghệ',
  'Giáo dục quốc phòng và an ninh',
  'Giáo dục thể chất',
  'Môn khác',
];

/// Normalized topic headings checked against the Ministry-authored 123-page
/// mathematics curriculum, mirrored by THCS An Đồng. No textbook ordering,
/// current class pace, semester coverage, or latest-consolidation claim.
class CurriculumCatalog {
  static const mathSource =
      'https://thcsandong.haiphong.edu.vn/van-ban-bo-gddt/chuong-trinh-giao-duc-pho-thong-mon-toan-ban-hanh-kem-theo-thong-tu-so-322018tt/vbctmb/20343/91425';
  static LearningCourse courseFor(
    String subject,
    int grade, {
    String textbook = '',
  }) {
    if (subject == 'Toán' && grade == 11) {
      const headings = <String, int>{
        'Góc lượng giác, giá trị và công thức lượng giác': 89,
        'Hàm số lượng giác và đồ thị': 90,
        'Phương trình lượng giác cơ bản': 91,
        'Dãy số': 91,
        'Cấp số cộng': 91,
        'Cấp số nhân': 92,
        'Giới hạn của dãy số': 92,
        'Giới hạn của hàm số': 93,
        'Hàm số liên tục': 93,
        'Lũy thừa với số mũ thực': 94,
        'Lôgarit': 94,
        'Hàm số mũ và hàm số lôgarit': 94,
        'Phương trình, bất phương trình mũ và lôgarit': 95,
        'Đạo hàm và ý nghĩa': 95,
        'Quy tắc tính đạo hàm': 96,
        'Đạo hàm cấp hai': 96,
        'Đường thẳng và mặt phẳng trong không gian': 97,
        'Quan hệ song song trong không gian': 97,
        'Quan hệ vuông góc trong không gian': 99,
        'Khoảng cách trong không gian': 100,
        'Góc giữa đường thẳng và mặt phẳng, góc nhị diện': 100,
        'Hình chóp cụt đều và thể tích': 101,
        'Số đặc trưng đo xu thế trung tâm của mẫu số liệu ghép nhóm': 101,
        'Biến cố hợp, giao và độc lập': 102,
        'Quy tắc tính xác suất': 102,
      };
      var index = 0;
      return LearningCourse(
        id: 'vn2018/math/11',
        subject: subject,
        textbook: textbook,
        sourceLabel: 'CT môn Toán 2018 · bản đăng bởi THCS An Đồng. Không phải thứ tự SGK hay lịch dạy của lớp.',
        topics: headings.entries
            .map(
              (e) => LearningTopic(
                id: 'vn2018/math/11/${++index}',
                title: e.key,
                sourceRef: '$mathSource#pdf-page=${e.value}',
              ),
            )
            .toList(),
      );
    }
    return LearningCourse(
      id: 'course/$grade/${Uri.encodeComponent(subject)}',
      subject: subject,
      textbook: textbook,
      sourceLabel: 'Chưa có danh mục đã đối chiếu cho môn/lớp này. Bạn có thể thêm chủ đề theo bài trên lớp; không dùng AI tự bịa chương trình.',
    );
  }
}
