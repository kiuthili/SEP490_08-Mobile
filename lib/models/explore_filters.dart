/// Bộ lọc tìm tour, khớp query `GET /api/tours/search`.
class ExploreFilters {
  static const maxPrice = 100000000;
  static const maxDurationDays = 30;

  String searchTerm;
  String city;
  String country;
  int? categoryId;
  int minPrice;
  int maxPriceValue;
  int durationDays;
  DateTime? startDate;
  DateTime? endDate;
  String? sortBy;

  ExploreFilters({
    this.searchTerm = '',
    this.city = '',
    this.country = '',
    this.categoryId,
    this.minPrice = 0,
    this.maxPriceValue = maxPrice,
    this.durationDays = 0,
    this.startDate,
    this.endDate,
    this.sortBy,
  });

  ExploreFilters copyWith({
    String? searchTerm,
    String? city,
    String? country,
    int? categoryId,
    bool clearCategory = false,
    int? minPrice,
    int? maxPriceValue,
    int? durationDays,
    DateTime? startDate,
    DateTime? endDate,
    bool clearStartDate = false,
    bool clearEndDate = false,
    String? sortBy,
    bool clearSort = false,
  }) {
    return ExploreFilters(
      searchTerm: searchTerm ?? this.searchTerm,
      city: city ?? this.city,
      country: country ?? this.country,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      minPrice: minPrice ?? this.minPrice,
      maxPriceValue: maxPriceValue ?? this.maxPriceValue,
      durationDays: durationDays ?? this.durationDays,
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      sortBy: clearSort ? null : (sortBy ?? this.sortBy),
    );
  }

  int get activeFilterCount {
    var n = 0;
    if (city.isNotEmpty) n++;
    if (country.isNotEmpty) n++;
    if (categoryId != null) n++;
    if (minPrice > 0 || maxPriceValue < maxPrice) n++;
    if (durationDays > 0) n++;
    if (startDate != null || endDate != null) n++;
    if (sortBy != null) n++;
    return n;
  }

  String? get startDateIso => startDate?.toIso8601String().substring(0, 10);

  String? get endDateIso => endDate?.toIso8601String().substring(0, 10);
}

const exploreSortOptions = <String?, String>{
  null: 'Mặc định',
  'price_asc': 'Giá thấp → cao',
  'price_desc': 'Giá cao → thấp',
  'date_asc': 'Khởi hành sớm',
  'date_desc': 'Khởi hành muộn',
};
