import 'package:flutter/material.dart';

class LocationService {
  // List of supported countries
  static const List<String> countries = [
    'Malaysia',
    'Singapore',
    'Indonesia',
    'Thailand',
    'Vietnam',
    'Philippines',
    'Myanmar',
    'Cambodia',
    'Brunei',
    'Laos',
    'United States',
    'United Kingdom',
    'Japan',
    'South Korea',
    'China',
  ];

  // States/Provinces for each country
  static const Map<String, List<String>> states = {
    'Malaysia': [
      'Johor', 'Kedah', 'Kelantan', 'Kuala Lumpur', 'Labuan',
      'Melaka', 'Negeri Sembilan', 'Pahang', 'Penang', 'Perak',
      'Perlis', 'Putrajaya', 'Sabah', 'Sarawak', 'Selangor', 'Terengganu'
    ],
    'Singapore': ['Central', 'East', 'North', 'North-East', 'West'],
    'Indonesia': ['Jakarta', 'West Java', 'Central Java', 'East Java', 'Bali'],
    'Thailand': ['Bangkok', 'Chiang Mai', 'Phuket', 'Pattaya', 'Krabi'],
    'Vietnam': ['Ho Chi Minh', 'Hanoi', 'Da Nang', 'Hai Phong', 'Can Tho'],
    'Philippines': ['Metro Manila', 'Cebu', 'Davao', 'Laguna', 'Cavite'],
    'Myanmar': ['Yangon', 'Mandalay', 'Naypyidaw', 'Bago', 'Mawlamyine'],
    'Cambodia': ['Phnom Penh', 'Siem Reap', 'Battambang', 'Sihanoukville'],
    'Brunei': ['Brunei-Muara', 'Belait', 'Tutong', 'Temburong'],
    'Laos': ['Vientiane', 'Luang Prabang', 'Savannakhet', 'Pakse'],

    // United States
    'United States': [
      'California', 'Texas', 'New York', 'Florida', 'Illinois',
      'Pennsylvania', 'Ohio', 'Georgia', 'North Carolina', 'Michigan',
      'New Jersey', 'Virginia', 'Washington', 'Arizona', 'Massachusetts',
      'Tennessee', 'Indiana', 'Missouri', 'Maryland', 'Wisconsin',
      'Colorado', 'Minnesota', 'South Carolina', 'Alabama', 'Louisiana',
      'Kentucky', 'Oregon', 'Oklahoma', 'Connecticut', 'Iowa',
      'Mississippi', 'Arkansas', 'Utah', 'Nevada', 'New Mexico',
      'West Virginia', 'Nebraska', 'Idaho', 'Hawaii', 'Maine',
      'New Hampshire', 'Rhode Island', 'Montana', 'Delaware', 'South Dakota',
      'North Dakota', 'Alaska', 'Vermont', 'Wyoming', 'District of Columbia'
    ],

    // United Kingdom
    'United Kingdom': [
      'England', 'Scotland', 'Wales', 'Northern Ireland',
      'Greater London', 'Greater Manchester', 'West Midlands', 'West Yorkshire',
      'Merseyside', 'Tyne and Wear', 'South Yorkshire'
    ],

    // Japan
    'Japan': [
      'Tokyo', 'Osaka', 'Kyoto', 'Hokkaido', 'Fukuoka',
      'Kanagawa', 'Saitama', 'Chiba', 'Hyogo', 'Aichi',
      'Shizuoka', 'Ibaraki', 'Hiroshima', 'Miyagi', 'Nagano'
    ],

    // South Korea
    'South Korea': [
      'Seoul', 'Busan', 'Incheon', 'Daegu', 'Daejeon',
      'Gwangju', 'Suwon', 'Ulsan', 'Changwon', 'Seongnam'
    ],

    // China
    'China': [
      'Beijing', 'Shanghai', 'Guangdong', 'Shenzhen', 'Jiangsu',
      'Zhejiang', 'Sichuan', 'Hubei', 'Shandong', 'Tianjin',
      'Chongqing', 'Fujian', 'Henan', 'Anhui', 'Hunan'
    ],
  };

  // Cities for each state/province
  static const Map<String, List<String>> cities = {
    // Malaysia cities
    'Johor': ['Johor Bahru', 'Batu Pahat', 'Muar', 'Kluang', 'Kulai'],
    'Kedah': ['Alor Setar', 'Sungai Petani', 'Kulim', 'Langkawi'],
    'Kelantan': ['Kota Bharu', 'Pasir Mas', 'Tanah Merah'],
    'Kuala Lumpur': ['KLCC', 'Bukit Bintang', 'Cheras', 'Setapak', 'Wangsa Maju'],
    'Labuan': ['Labuan Town', 'Victoria'],
    'Melaka': ['Melaka City', 'Ayer Keroh', 'Jasin'],
    'Negeri Sembilan': ['Seremban', 'Nilai', 'Port Dickson'],
    'Pahang': ['Kuantan', 'Cameron Highlands', 'Genting Highlands'],
    'Penang': ['George Town', 'Bayan Lepas', 'Butterworth'],
    'Perak': ['Ipoh', 'Taiping', 'Teluk Intan'],
    'Perlis': ['Kangar', 'Padang Besar'],
    'Putrajaya': ['Putrajaya'],
    'Sabah': ['Kota Kinabalu', 'Sandakan', 'Tawau'],
    'Sarawak': ['Kuching', 'Miri', 'Sibu'],
    'Selangor': ['Shah Alam', 'Petaling Jaya', 'Subang Jaya', 'Klang'],
    'Terengganu': ['Kuala Terengganu', 'Kemaman', 'Dungun'],

    // United States
    'California': ['Los Angeles', 'San Francisco', 'San Diego', 'San Jose', 'Sacramento'],
    'Texas': ['Houston', 'Dallas', 'Austin', 'San Antonio', 'Fort Worth'],
    'New York': ['New York City', 'Buffalo', 'Rochester', 'Yonkers', 'Syracuse'],
    'Florida': ['Miami', 'Orlando', 'Tampa', 'Jacksonville', 'St. Petersburg'],
    'Illinois': ['Chicago', 'Aurora', 'Rockford', 'Joliet', 'Naperville'],

    // United Kingdom
    'England': ['London', 'Manchester', 'Birmingham', 'Liverpool', 'Bristol'],
    'Scotland': ['Edinburgh', 'Glasgow', 'Aberdeen', 'Dundee', 'Inverness'],
    'Wales': ['Cardiff', 'Swansea', 'Newport', 'Bangor', 'St Davids'],
    'Greater London': ['Central London', 'Westminster', 'Camden', 'Greenwich'],

    // Japan
    'Tokyo': ['Shinjuku', 'Shibuya', 'Chiyoda', 'Minato', 'Shinagawa'],
    'Osaka': ['Kita', 'Minami', 'Namba', 'Shinsaibashi', 'Umeda'],
    'Kyoto': ['Shimogyo', 'Kamigyo', 'Sakyo', 'Nakagyo', 'Higashiyama'],
    'Hokkaido': ['Sapporo', 'Hakodate', 'Asahikawa', 'Otaru'],

    // South Korea
    'Seoul': ['Gangnam', 'Myeongdong', 'Hongdae', 'Itaewon', 'Jongno'],
    'Busan': ['Haeundae', 'Seomyeon', 'Gwangalli', 'Nampo-dong'],
    'Incheon': ['Songdo', 'Bupyeong', 'Namdong', 'Gyeyang'],

    // China
    'Beijing': ['Dongcheng', 'Xicheng', 'Chaoyang', 'Haidian', 'Fengtai'],
    'Shanghai': ['Pudong', 'Huangpu', 'Jing\'an', 'Xuhui', 'Changning'],
    'Guangdong': ['Guangzhou', 'Shenzhen', 'Dongguan', 'Foshan', 'Zhuhai'],
    'Shenzhen': ['Nanshan', 'Futian', 'Luohu', 'Bao\'an', 'Longgang'],

    'Default': [],
  };

  // Postal codes mapping
  static const Map<String, String> postalCodes = {
    // Malaysia
    'Johor Bahru': '80000', 'Batu Pahat': '83000', 'Muar': '84000', 'Kluang': '86000',
    'Alor Setar': '05000', 'Sungai Petani': '08000', 'Kulim': '09000', 'Langkawi': '07000',
    'Kota Bharu': '15000', 'George Town': '10000', 'Butterworth': '12000',
    'Ipoh': '30000', 'Taiping': '34000', 'Teluk Intan': '36000',
    'Kuala Lumpur': '50000', 'KLCC': '50088', 'Bukit Bintang': '55100',
    'Shah Alam': '40000', 'Petaling Jaya': '47300', 'Subang Jaya': '47500', 'Klang': '41000',
    'Kuching': '93000', 'Miri': '98000', 'Sibu': '96000',
    'Kota Kinabalu': '88000', 'Sandakan': '90000', 'Tawau': '91000',
    'Melaka City': '75000', 'Seremban': '70000', 'Nilai': '71800',
    'Kuantan': '25000', 'Kuala Terengganu': '20000', 'Kangar': '01000',
    'Putrajaya': '62000', 'Labuan Town': '87000',

    // United States
    'New York City': '10001', 'Los Angeles': '90001', 'Chicago': '60601', 'Houston': '77001',
    'San Francisco': '94101', 'Boston': '02101', 'Seattle': '98101', 'Miami': '33101',
    'Dallas': '75201', 'Atlanta': '30301', 'Washington DC': '20001', 'Philadelphia': '19101',

    // United Kingdom
    'London': 'SW1A 1AA', 'Manchester': 'M1 1AE', 'Birmingham': 'B1 1TT', 'Liverpool': 'L1 1AA',
    'Edinburgh': 'EH1 1AA', 'Glasgow': 'G1 1AA', 'Cardiff': 'CF10 1AA', 'Belfast': 'BT1 1AA',

    // Japan
    'Tokyo': '100-0001', 'Osaka': '530-0001', 'Kyoto': '600-8001', 'Yokohama': '220-0001',
    'Sapporo': '060-0001', 'Fukuoka': '810-0001', 'Nagoya': '460-0001',

    // South Korea
    'Seoul': '03087', 'Busan': '48940', 'Incheon': '22186', 'Daegu': '41900', 'Daejeon': '34800',
    'Gangnam': '06000', 'Myeongdong': '04536',

    // China
    'Beijing': '100000', 'Shanghai': '200000', 'Guangzhou': '510000', 'Shenzhen': '518000',
    'Chengdu': '610000', 'Wuhan': '430000', 'Xi\'an': '710000', 'Hangzhou': '310000',
  };

  static String? getPostalCode(String city) {
    return postalCodes[city];
  }

  static List<String> getStatesForCountry(String country) {
    return states[country] ?? [];
  }

  static List<String> getCitiesForState(String state) {
    return cities[state] ?? [];
  }
}

// StateCitySelector with Country Selection - Optional City Support
class StateCitySelector extends StatefulWidget {
  final String? initialCountry;
  final String? initialState;
  final String? initialCity;
  final Function(String country, String state, String? city, String postalCode) onSelected;

  const StateCitySelector({
    super.key,
    this.initialCountry,
    this.initialState,
    this.initialCity,
    required this.onSelected,
  });

  @override
  State<StateCitySelector> createState() => _StateCitySelectorState();
}

class _StateCitySelectorState extends State<StateCitySelector> {
  String _selectedCountry = 'Malaysia';
  String? _selectedState;
  String? _selectedCity;
  String _postalCode = '';

  List<String> get _availableCountries => LocationService.countries;

  List<String> get _availableStates {
    return LocationService.getStatesForCountry(_selectedCountry);
  }

  List<String> get _availableCities {
    if (_selectedState == null) return [];
    return LocationService.getCitiesForState(_selectedState!);
  }

  bool get _hasCities => _selectedState != null && _availableCities.isNotEmpty;
  bool get _hasNoCities => _selectedState != null && _availableCities.isEmpty;

  @override
  void initState() {
    super.initState();
    if (widget.initialCountry != null && _availableCountries.contains(widget.initialCountry)) {
      _selectedCountry = widget.initialCountry!;
    }

    if (widget.initialState != null && _availableStates.contains(widget.initialState)) {
      _selectedState = widget.initialState;
    }

    if (widget.initialCity != null &&
        _selectedState != null &&
        _hasCities &&
        _availableCities.contains(widget.initialCity)) {
      _selectedCity = widget.initialCity;
      _postalCode = LocationService.getPostalCode(_selectedCity!) ?? '';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_selectedState != null) {
          widget.onSelected(_selectedCountry, _selectedState!, _selectedCity, _postalCode);
        }
      });
    } else if (_hasNoCities) {
      // If no cities available, city is automatically null
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_selectedState != null) {
          widget.onSelected(_selectedCountry, _selectedState!, null, '');
        }
      });
    }
  }

  void _updateSelection() {
    if (_selectedState != null) {
      widget.onSelected(_selectedCountry, _selectedState!, _selectedCity, _postalCode);
    }
  }

  void _showCountrySelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              const Text('Select Country',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: _availableCountries.length,
                  itemBuilder: (context, index) {
                    final country = _availableCountries[index];
                    return ListTile(
                      title: Text(country),
                      onTap: () {
                        Navigator.pop(context);
                        setState(() {
                          _selectedCountry = country;
                          _selectedState = null;
                          _selectedCity = null;
                          _postalCode = '';
                        });
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showStateSelector() {
    if (_availableStates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No states available for this country')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              Text('Select State in $_selectedCountry',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: _availableStates.length,
                  itemBuilder: (context, index) {
                    final state = _availableStates[index];
                    return ListTile(
                      title: Text(state),
                      onTap: () {
                        Navigator.pop(context);
                        setState(() {
                          _selectedState = state;
                          _selectedCity = null;
                          _postalCode = '';
                        });
                        _updateSelection();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCitySelector() {
    if (_selectedState == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a state first')),
      );
      return;
    }

    if (_availableCities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No cities available for ${_selectedState!} - city is optional')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              Text('Select City in $_selectedState',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: _availableCities.length,
                  itemBuilder: (context, index) {
                    final city = _availableCities[index];
                    return ListTile(
                      title: Text(city),
                      onTap: () {
                        Navigator.pop(context);
                        setState(() {
                          _selectedCity = city;
                          _postalCode = LocationService.getPostalCode(city) ?? '';
                        });
                        _updateSelection();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Country Selector
        const Text('Country *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 8),
        InkWell(
          onTap: _showCountrySelector,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_selectedCountry, style: const TextStyle(fontSize: 14)),
                const Icon(Icons.arrow_drop_down, color: Colors.grey),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // State Selector
        const Text('State *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 8),
        InkWell(
          onTap: _showStateSelector,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedState ?? 'Select State/Province',
                  style: TextStyle(
                    color: _selectedState != null ? Colors.black : Colors.grey,
                    fontSize: 14,
                  ),
                ),
                const Icon(Icons.arrow_drop_down, color: Colors.grey),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // City Selector - Dynamic based on whether cities exist
        if (_hasCities) ...[
          // Cities exist - show required field
          const Text('City *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 8),
          InkWell(
            onTap: _showCitySelector,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedCity ?? 'Select City',
                    style: TextStyle(
                      color: _selectedCity != null ? Colors.black : Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, color: Colors.grey),
                ],
              ),
            ),
          ),
          if (_selectedCity == null)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 12),
              child: Text(
                'Please select a city',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ),
        ] else if (_hasNoCities) ...[
          // No cities available - show optional field with different label
          const Text('City (Optional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey.shade100,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'No city selection needed',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                Icon(Icons.info_outline, color: Colors.grey.shade400, size: 18),
              ],
            ),
          ),

        ] else if (_selectedState == null) ...[
          // No state selected yet
          const Text('City', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey.shade50,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select state first',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 14,
                  ),
                ),
                Icon(Icons.arrow_drop_down, color: Colors.grey.shade300),
              ],
            ),
          ),
        ],

        // Postal Code Display
        if (_postalCode.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.local_post_office, size: 16, color: Colors.green),
                const SizedBox(width: 8),
                Text('Postal Code: $_postalCode',
                    style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.green)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}