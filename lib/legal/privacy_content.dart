import 'legal_section.dart';

const privacySectionsViLastUpdated = '3 tháng 6, 2026';

const privacySectionsVi = <LegalSection>[
  LegalSection(
    id: 'introduction',
    title: 'Giới thiệu',
    paragraphs: [
      'StayHub ("chúng tôi") tôn trọng quyền riêng tư của bạn và cam kết bảo vệ dữ liệu cá nhân. Chính sách quyền riêng tư này giải thích cách chúng tôi thu thập, sử dụng, tiết lộ, lưu trữ và bảo vệ thông tin khi bạn truy cập website, dùng ứng dụng di động, tạo tài khoản, đặt chỗ hoặc tương tác với dịch vụ (gọi chung là "Nền tảng").',
      'Chính sách này áp dụng cho du khách, chủ tài khoản, Đối tác tour và khách truy cập. Bạn nên đọc cùng Điều khoản dịch vụ. Khi sử dụng Nền tảng, bạn xác nhận đã đọc và hiểu Chính sách này.',
      'StayHub xử lý dữ liệu cá nhân phù hợp Luật An toàn thông tin mạng và Luật An ninh mạng Việt Nam, Nghị định số 13/2023/NĐ-CP về bảo vệ dữ liệu cá nhân (hiệu lực từ tháng 7/2023), Luật Bảo vệ quyền lợi người tiêu dùng và quy định liên quan.',
    ],
  ),
  LegalSection(
    id: 'data-controller',
    title: 'Bên kiểm soát dữ liệu và liên hệ',
    paragraphs: [
      'StayHub là bên kiểm soát dữ liệu cá nhân xử lý qua Nền tảng, trừ khi Đối tác tour là bên kiểm soát độc lập đối với dữ liệu vận hành họ thu trực tiếp khi thực hiện tour.',
      'Liên hệ bảo vệ dữ liệu: privacy@stayhub.com | Hỗ trợ chung: hi@stayhub.com | Địa chỉ: Thành phố Hồ Chí Minh, Việt Nam.',
      'Với yêu cầu liên quan dữ liệu cá nhân, vui lòng cung cấp đủ thông tin xác minh danh tính. Chúng tôi có thể yêu cầu xác minh bổ sung trước khi xử lý yêu cầu nhạy cảm.',
    ],
  ),
  LegalSection(
    id: 'data-collected',
    title: 'Các loại dữ liệu cá nhân chúng tôi thu thập',
    paragraphs: [
      'Chúng tôi thu thập dữ liệu bạn cung cấp trực tiếp, dữ liệu phát sinh khi dùng Nền tảng và dữ liệu nhận từ bên thứ ba như đối tác thanh toán và dịch vụ đăng nhập mạng xã hội.',
    ],
    bullets: [
      'Dữ liệu định danh và hồ sơ: họ tên, tên đăng nhập, ngày sinh, giới tính, ảnh đại diện, số giấy tờ tùy thân khi tour hoặc hoàn tiền yêu cầu.',
      'Dữ liệu liên hệ: email, số điện thoại, địa chỉ, người liên hệ khẩn cấp.',
      'Dữ liệu tài khoản và xác thực: mật khẩu băm, lịch sử đăng nhập, token OAuth từ Google hoặc Facebook khi dùng đăng nhập mạng xã hội.',
      'Dữ liệu đặt chỗ và giao dịch: tour đã chọn, ngày đi, số khách, yêu cầu đặc biệt, metadata phương thức thanh toán, hóa đơn, hoàn tiền và mã voucher.',
      'Dữ liệu tài chính: token thẻ và thông tin thanh toán do đối tác tuân PCI-DSS xử lý (StayHub không lưu số thẻ đầy đủ trên máy chủ).',
      'Dữ liệu vị trí: tọa độ GPS khi bật theo dõi chuyến đi, chia sẻ vị trí với bạn bè hoặc tính năng bản đồ tour.',
      'Thông tin liên lạc: tin nhắn với Đối tác tour, phiếu hỗ trợ, nhật ký chat, ghi âm cuộc gọi khi được thông báo.',
      'Nội dung do người dùng tạo: đánh giá, xếp hạng, ảnh, khoảnh khắc xã hội, bình luận và danh sách yêu thích.',
      'Dữ liệu kỹ thuật: địa chỉ IP, mã thiết bị, trình duyệt, hệ điều hành, cookie, nhật ký phiên và sự kiện phân tích.',
      'Tùy chọn tiếp thị: đăng ký bản tin, đồng ý khuyến mãi và dữ liệu tương tác chiến dịch.',
    ],
  ),
  LegalSection(
    id: 'collection-methods',
    title: 'Phương thức thu thập dữ liệu cá nhân',
    bullets: [
      'Trực tiếp từ bạn khi đăng ký, hoàn tất đặt chỗ, cập nhật hồ sơ, gửi đánh giá hoặc liên hệ hỗ trợ.',
      'Tự động qua cookie, pixel, nhật ký máy chủ và công nghệ tương tự khi bạn duyệt hoặc dùng tính năng Nền tảng.',
      'Từ bên thứ ba gồm cổng thanh toán, nhà cung cấp danh tính (Google, Facebook), nhà cung cấp phân tích, chống gian lận và Đối tác tour thực hiện đặt chỗ.',
      'Từ nguồn công khai khi hợp pháp và phục vụ chống gian lận hoặc xác minh doanh nghiệp.',
    ],
  ),
  LegalSection(
    id: 'legal-bases',
    title: 'Cơ sở pháp lý và mục đích xử lý',
    paragraphs: [
      'Theo Nghị định 13/2023/NĐ-CP và pháp luật áp dụng, StayHub xử lý dữ liệu cá nhân dựa trên một hoặc nhiều cơ sở: đồng ý của bạn; thực hiện hợp đồng (dịch vụ tài khoản và đặt chỗ); tuân thủ nghĩa vụ pháp lý; bảo vệ lợi ích sống còn; và lợi ích hợp pháp không lấn át quyền của bạn.',
    ],
    bullets: [
      'Tạo và quản lý tài khoản, xác thực truy cập.',
      'Xử lý đặt chỗ, thanh toán, xác nhận, hủy và hoàn tiền.',
      'Thông báo cập nhật đặt chỗ, thay đổi lịch trình, cảnh báo an toàn và phản hồi hỗ trợ.',
      'Vận hành tính năng xã hội như kết bạn, chia sẻ khoảnh khắc và theo dõi vị trí tùy chọn.',
      'Cá nhân hóa kết quả tìm kiếm, gợi ý và ưu đãi.',
      'Vận hành tính năng lập kế hoạch tour hỗ trợ AI theo sở thích và truy vấn của bạn.',
      'Phát hiện, ngăn chặn và điều tra gian lận, lạm dụng và sự cố bảo mật.',
      'Tuân thủ thuế, kế toán, báo cáo du lịch và yêu cầu cơ quan chức năng.',
      'Cải thiện hiệu năng Nền tảng, phân tích và phát triển tính năng mới.',
      'Gửi thông tin tiếp thị khi pháp luật và tùy chọn của bạn cho phép.',
    ],
  ),
  LegalSection(
    id: 'sharing',
    title: 'Cách chúng tôi chia sẻ dữ liệu cá nhân',
    paragraphs: [
      'StayHub không bán dữ liệu cá nhân của bạn. Chúng tôi chỉ chia sẻ như mô tả dưới đây và yêu cầu bên nhận áp dụng biện pháp bảo vệ phù hợp.',
    ],
    bullets: [
      'Đối tác tour: chi tiết đặt chỗ, tên hành khách, liên hệ, ghi chú ăn uống/y tế bạn cung cấp và yêu cầu đặc biệt cần để thực hiện tour.',
      'Đối tác thanh toán và ngân hàng: số tiền giao dịch, mã thanh toán và tín hiệu gian lận để xử lý thanh toán và chargeback.',
      'Nhà cung cấp đám mây và CNTT: hạ tầng lưu trữ và xử lý dữ liệu thay mặt chúng tôi theo thỏa thuận xử lý dữ liệu.',
      'Công cụ hỗ trợ và liên lạc: email, SMS, thông báo đẩy và chat.',
      'Đối tác phân tích và tiếp thị: dữ liệu sử dụng tổng hợp hoặc ẩn danh; dữ liệu nhận diện chỉ khi có đồng ý khi luật yêu cầu.',
      'Nhà cung cấp đăng nhập mạng xã hội: token xác thực khi bạn chọn đăng nhập Google hoặc Facebook.',
      'Cơ quan pháp luật và quản lý: khi tòa án, trát đòi hoặc pháp luật Việt Nam yêu cầu.',
      'Giao dịch doanh nghiệp: trong sáp nhập, mua lại hoặc bán tài sản, có nghĩa vụ bảo mật.',
      'Người dùng khác: nội dung bạn chọn công khai, như đánh giá công khai hoặc khoảnh khắc công khai.',
    ],
  ),
  LegalSection(
    id: 'cross-border',
    title: 'Chuyển dữ liệu xuyên biên giới',
    paragraphs: [
      'StayHub và nhà cung cấp dịch vụ có thể lưu hoặc xử lý dữ liệu trên máy chủ tại Việt Nam và quốc gia khác. Khi dữ liệu cá nhân công dân Việt Nam được chuyển ra nước ngoài, chúng tôi áp dụng biện pháp theo Nghị định 13/2023/NĐ-CP, gồm đánh giá tác động khi cần, điều khoản hợp đồng và thông báo/đăng ký với cơ quan có thẩm quyền khi bắt buộc.',
      'Khi sử dụng Nền tảng, bạn thừa nhận dữ liệu có thể được chuyển quốc tế cho các mục đích trong Chính sách này, với biện pháp bảo vệ phù hợp.',
    ],
  ),
  LegalSection(
    id: 'retention',
    title: 'Lưu trữ dữ liệu',
    paragraphs: [
      'Chúng tôi chỉ lưu dữ liệu cá nhân trong thời gian cần thiết cho mục đích trong Chính sách này, trừ khi luật yêu cầu hoặc cho phép lưu lâu hơn.',
    ],
    bullets: [
      'Dữ liệu tài khoản: trong thời gian tài khoản hoạt động và một khoảng hợp lý sau khi đóng để giải quyết tranh chấp và tuân thủ pháp luật.',
      'Hồ sơ đặt chỗ và tài chính: thường tối thiểu năm (5) đến mười (10) năm theo quy định kế toán và thuế Việt Nam.',
      'Dữ liệu tiếp thị: đến khi bạn rút đồng ý hoặc phản đối, cộng thời gian ngắn để tôn trọng yêu cầu từ chối.',
      'Nhật ký kỹ thuật và bảo mật: trong thời hạn giới hạn theo nhu cầu bảo mật và xử lý sự cố.',
      'Khi không còn cần thiết, chúng tôi xóa, ẩn danh hoặc tổng hợp dữ liệu để ngăn nhận diện lại khi khả thi.',
    ],
  ),
  LegalSection(
    id: 'security',
    title: 'Biện pháp bảo mật',
    paragraphs: [
      'StayHub áp dụng biện pháp quản trị, kỹ thuật và tổ chức nhằm bảo vệ dữ liệu cá nhân khỏi truy cập, mất mát, phá hủy hoặc thay đổi trái phép. Biện pháp gồm mã hóa truyền tải (TLS/HTTPS), kiểm soát truy cập, phân quyền, thực hành phát triển an toàn và giám sát hoạt động bất thường.',
      'Không có phương thức truyền hoặc lưu trữ nào an toàn tuyệt đối. Bạn chịu trách nhiệm bảo mật thông tin đăng nhập và đăng xuất trên thiết bị dùng chung.',
      'Khi xảy ra sự cố rò rỉ dữ liệu cá nhân có thể ảnh hưởng quyền của bạn, chúng tôi thông báo cho cá nhân liên quan và cơ quan có thẩm quyền theo pháp luật Việt Nam, gồm Nghị định 13/2023/NĐ-CP.',
    ],
  ),
  LegalSection(
    id: 'your-rights',
    title: 'Quyền của bạn theo pháp luật Việt Nam',
    paragraphs: [
      'Trong phạm vi pháp luật và yêu cầu xác minh, bạn có thể thực hiện các quyền sau đối với dữ liệu cá nhân:',
    ],
    bullets: [
      'Quyền được thông báo về hoạt động xử lý và Chính sách này.',
      'Quyền truy cập dữ liệu cá nhân chúng tôi đang lưu về bạn.',
      'Quyền sửa dữ liệu không chính xác hoặc chưa đầy đủ.',
      'Quyền xóa khi xử lý không còn cần thiết hoặc bạn rút đồng ý, trừ ngoại lệ lưu trữ theo luật.',
      'Quyền hạn chế xử lý trong một số trường hợp.',
      'Quyền di chuyển dữ liệu bạn cung cấp, ở định dạng có cấu trúc, phổ biến khi kỹ thuật cho phép.',
      'Quyền phản đối xử lý dựa trên lợi ích hợp pháp hoặc tiếp thị trực tiếp.',
      'Quyền rút đồng ý bất cứ lúc nào, không ảnh hưởng tính hợp pháp của xử lý trước khi rút.',
      'Quyền khiếu nại với Bộ Công an Việt Nam hoặc cơ quan có thẩm quyền về bảo vệ dữ liệu cá nhân.',
    ],
  ),
  LegalSection(
    id: 'cookies',
    title: 'Cookie và công nghệ tương tự',
    paragraphs: [
      'StayHub dùng cookie, local storage và công nghệ tương tự để vận hành chức năng cốt lõi, ghi nhớ tùy chọn, phân tích lưu lượng và cung cấp nội dung phù hợp.',
    ],
    bullets: [
      'Cookie thiết yếu: cần cho đăng nhập, quản lý phiên, bảo mật và thanh toán.',
      'Cookie chức năng: ghi nhớ ngôn ngữ, tiền tệ và hiển thị.',
      'Cookie phân tích: giúp hiểu cách sử dụng và cải thiện hiệu năng.',
      'Cookie tiếp thị: đo hiệu quả chiến dịch và cá nhân hóa ưu đãi khi bạn đã đồng ý.',
      'Bạn có thể quản lý cookie qua cài đặt trình duyệt. Tắt một số cookie có thể hạn chế chức năng Nền tảng.',
    ],
  ),
  LegalSection(
    id: 'children',
    title: 'Quyền riêng tư trẻ em',
    paragraphs: [
      'Nền tảng không hướng tới trẻ em dưới 16 tuổi. Chúng tôi không cố ý thu thập dữ liệu cá nhân từ trẻ dưới 16 khi chưa có sự đồng ý có thể xác minh của cha mẹ. Nếu bạn cho rằng chúng tôi đã thu thập dữ liệu trẻ em không hợp lệ, liên hệ privacy@stayhub.com để chúng tôi xóa thông tin đó.',
      'Đặt chỗ cho trẻ vị thành niên phải do cha mẹ hoặc người giám hộ hợp pháp thực hiện và cung cấp thông tin hành khách cần thiết.',
    ],
  ),
  LegalSection(
    id: 'automated-decisions',
    title: 'Xử lý tự động và tính năng AI',
    paragraphs: [
      'StayHub có thể dùng hệ thống tự động, gồm AI gợi ý tour và trợ lý lập kế hoạch, để đề xuất tour, lịch trình và nội dung theo sở thích, lịch sử tìm kiếm và mẫu người dùng tương tự.',
      'Các hệ thống này không tạo hiệu lực pháp lý hoặc tác động tương đương mà không có rà soát của con người. Bạn có thể liên hệ hỗ trợ để biết cách gợi ý được tạo hoặc góp ý về kết quả tự động.',
    ],
  ),
  LegalSection(
    id: 'third-party-links',
    title: 'Website và dịch vụ bên thứ ba',
    paragraphs: [
      'Nền tảng có thể chứa liên kết đến website, bản đồ, trang thanh toán hoặc mạng xã hội bên thứ ba. Chính sách này không áp dụng cho các bên đó. Bạn nên đọc chính sách quyền riêng tư của họ trước khi cung cấp dữ liệu cá nhân.',
    ],
  ),
  LegalSection(
    id: 'marketing',
    title: 'Thông tin tiếp thị',
    paragraphs: [
      'Khi có đồng ý hoặc pháp luật cho phép, chúng tôi có thể gửi email khuyến mãi, thông báo đẩy hoặc SMS về tour, ưu đãi và cập nhật Nền tảng. Bạn có thể từ chối bất cứ lúc nào qua liên kết hủy đăng ký trong email, cài đặt thông báo trong tài khoản hoặc email privacy@stayhub.com.',
      'Thông báo giao dịch và dịch vụ (xác nhận đặt chỗ, cảnh báo an toàn, đặt lại mật khẩu) vẫn được gửi kể cả khi bạn từ chối tiếp thị.',
    ],
  ),
  LegalSection(
    id: 'changes',
    title: 'Thay đổi Chính sách quyền riêng tư',
    paragraphs: [
      'Chúng tôi có thể cập nhật Chính sách này để phản ánh thay đổi pháp luật, công nghệ hoặc thực tiễn. Ngày "Cập nhật lần cuối" ở đầu trang cho biết phiên bản mới nhất. Thay đổi quan trọng sẽ được thông báo qua Nền tảng, email hoặc kênh phù hợp khác.',
      'Việc tiếp tục sử dụng Nền tảng sau ngày hiệu lực của Chính sách cập nhật được coi là bạn đã biết thay đổi, trừ khi luật yêu cầu đồng ý riêng.',
    ],
  ),
  LegalSection(
    id: 'contact',
    title: 'Liên hệ',
    paragraphs: [
      'Về quyền riêng tư, yêu cầu chủ thể dữ liệu hoặc khiếu nại:',
      'Email: privacy@stayhub.com | Pháp lý: legal@stayhub.com | Hỗ trợ: hi@stayhub.com',
      'StayHub — Thành phố Hồ Chí Minh, Việt Nam',
    ],
  ),
];
