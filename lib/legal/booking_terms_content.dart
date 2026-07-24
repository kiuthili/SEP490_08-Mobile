import 'legal_section.dart';

const bookingTermsSectionsViLastUpdated = 'Ngày 22 tháng 7, 2026';

const bookingTermsSectionsVi = <LegalSection>[
  LegalSection(
    id: 'booking-rules',
    title: 'Quy Định Đặt Chỗ Chung',
    paragraphs: [
      'Khi đặt tour hoặc trải nghiệm trên StayHub, bạn đồng ý cung cấp thông tin chính xác và đầy đủ cho tất cả hành khách.',
      'StayHub giới hạn số lượng tối đa 9 vé cho mỗi đơn hàng để đảm bảo chất lượng nhóm và tránh hiện tượng gom vé số lượng lớn. Nếu bạn cần đặt chỗ cho đoàn đông hơn, vui lòng liên hệ bộ phận hỗ trợ khách hàng của chúng tôi.',
    ],
  ),
  LegalSection(
    id: 'age-requirements',
    title: 'Yêu Cầu & Giới Hạn Độ Tuổi',
    paragraphs: [
      'Các loại vé khác nhau có thể có giới hạn độ tuổi cụ thể. Bạn có trách nhiệm đảm bảo rằng độ tuổi của hành khách được chỉ định nằm trong phạm vi cho phép của loại vé đã chọn.',
    ],
    bullets: [
      'Vé Trẻ Em / Em Bé: Bất kỳ vé nào dành cho trẻ em hoặc em bé (hoặc quy định dành riêng cho người dưới 12 tuổi) đều phải có ít nhất một vé Người lớn đi kèm trong cùng một đơn đặt.',
      'Nếu tuổi của hành khách (được tính từ Ngày Sinh đến ngày hiện tại) không đáp ứng yêu cầu độ tuổi của loại vé, bạn sẽ không thể tiếp tục đặt chỗ.',
      'Đối tác Tour có quyền xác minh độ tuổi của hành khách bằng giấy tờ tùy thân hợp lệ (CMND/CCCD, Hộ chiếu, hoặc Giấy khai sinh) vào ngày khởi hành. Nếu có sự sai lệch, bạn có thể bị từ chối phục vụ mà không được hoàn tiền.',
    ],
  ),
  LegalSection(
    id: 'vouchers',
    title: 'Voucher & Khuyến Mãi',
    paragraphs: [
      'Bạn có thể áp dụng Voucher hoặc Mã giảm giá tại bước thanh toán. Chỉ một voucher được sử dụng cho mỗi đơn hàng.',
      'Nếu bạn đã áp dụng voucher cho đơn hàng và sau đó hủy đơn (hoặc không thanh toán thành công), voucher sẽ không được hoàn lại hoặc khôi phục dưới bất kỳ hình thức nào. Giá trị khuyến mãi là không được hoàn trả.',
    ],
  ),
  LegalSection(
    id: 'cancellations',
    title: 'Chính Sách Hủy Vé & Hoàn Tiền',
    paragraphs: [
      'Bằng việc hoàn tất thanh toán, bạn đồng ý với chính sách hủy vé cụ thể của tour đó. Trừ khi có quy định khác trên trang chi tiết tour, chính sách hủy vé tiêu chuẩn của chúng tôi như sau:',
    ],
    bullets: [
      'Hủy trước hơn 15 ngày so với ngày khởi hành: Phí hủy 0% (Hoàn 100%).',
      'Hủy từ 11 - 15 ngày trước ngày khởi hành: Phí hủy 5%.',
      'Hủy từ 6 - 10 ngày trước ngày khởi hành: Phí hủy 10%.',
      'Hủy từ 3 - 5 ngày trước ngày khởi hành: Phí hủy 15%.',
      'Hủy từ 1 - 2 ngày trước ngày khởi hành: Phí hủy 20%.',
    ],
  ),
  LegalSection(
    id: 'information-verification',
    title: 'Xác Thực Thông Tin',
    paragraphs: [
      'Tất cả thông tin hành khách (Họ và Tên, CMND/CCCD/Hộ chiếu, Ngày sinh, Quốc tịch) phải khớp chính xác với giấy tờ tùy thân chính thức của hành khách.',
      'Bạn phải mang theo giấy tờ tùy thân bản gốc (CMND/CCCD, Hộ chiếu, hoặc Giấy khai sinh đối với trẻ em) vào ngày đi tour.',
      'Mọi sự sai lệch giữa thông tin đặt chỗ và giấy tờ thực tế của hành khách có thể dẫn đến việc Đối tác Tour từ chối cung cấp dịch vụ. StayHub không chịu trách nhiệm cho bất kỳ tổn thất nào phát sinh do việc cung cấp thông tin sai lệch trong quá trình đặt chỗ.',
    ],
  ),
];
