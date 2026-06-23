import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Crime Watch UK',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blueGrey,
),
      ),
      home: const MyHomePage(title: 'Crime Watch UK'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with SingleTickerProviderStateMixin {
  final TextEditingController postcodeController = TextEditingController();
  String searchedPostcode = '';
  List crimes = [];
  String crimeCategory = '';
  List<String> recentSearches = [];

  double? searchedLatitude;
  double? searchedLongitude;

  late AnimationController pulseController;
  late Animation<double> pulseAnimation;
  bool clusteringEnabled = true;

  final MapController mapController = MapController();
  final ScrollController scrollController = ScrollController();

  String selectedCrimeFilter = 'All Crimes';
  List<String> crimeFilters = ['All Crimes'];
  List filteredCrimes = [];
  bool isLoading = false;
  String errorMessage = '';
  int crimeTypesCount = 0;
  String latestCrimeMonth = '';
  String mostCommonCrime = '';
  String riskLevel = '';
  List<MapEntry<String, int>> topCrimeTypes = [];

  Color riskColor = Colors.green;

  Future<Map<String, dynamic>?> getCoordinatesFromPostcode() async {
   final postcode = postcodeController.text.trim();

final postcodeUrl = Uri.parse(
  'https://api.postcodes.io/postcodes/$postcode',
);

    final response = await http.get(postcodeUrl);

    final data = jsonDecode(response.body);

    print('POSTCODE LOOKUP SUCCESS');

    if (data['result'] == null) {
      return null;
    }

    searchedLatitude = data['result']['latitude'];
    searchedLongitude = data['result']['longitude'];

    return {
      'latitude': searchedLatitude,
      'longitude': searchedLongitude,
    };
  }
  Future<void> fetchCrimeData() async {
    print('FETCH STARTED');
    print('SEARCH STARTED');
    
    setState(() {

      isLoading = true;
    });
    try {
      final coordinates = await getCoordinatesFromPostcode();

      if (coordinates == null) {
        setState(() {
          errorMessage = 'Could not find postcode coordinates';
          isLoading = false;
        });
        return;
      }

      print(coordinates);

      final latitude = coordinates['latitude'];
      final longitude = coordinates['longitude'];

    setState(() {
      searchedLatitude = latitude;
      searchedLongitude = longitude;
    });

   WidgetsBinding.instance.addPostFrameCallback((_) {
  mapController.move(
    LatLng(latitude, longitude),
    15,
  );
});

    final url = Uri.parse(
      'https://data.police.uk/api/crimes-street/all-crime?lat=$latitude&lng=$longitude',);

    final response = await http.get(url);

    final data = jsonDecode(response.body);

    print('CRIMES FOUND: ${data.length}');

    if (data.isEmpty) {
      setState(() {
        errorMessage = 'No crimes found for this area';
        crimes = [];
        crimeCategory = '';
        isLoading = false;
      });

      return;
    }
    setState(() {
      crimes = data;

      crimeFilters = [
        'All Crimes',
        ...data
            .map<String>((crime) => crime['category'] as String)
            .toSet()
            .toList(),
      ];

      selectedCrimeFilter = 'All Crimes';

      filteredCrimes = data;

      crimeCategory = data[0]['category'];

      crimeTypesCount = data
          .map((crime) => crime['category'])
          .toSet()
          .length;

      latestCrimeMonth = data[0]['month'] ?? '';

      if (data.length >= 300) {
        riskLevel = 'High';
        riskColor = Colors.red;
      } else if (data.length >= 100) {
        riskLevel = 'Medium';
        riskColor = Colors.orange;
      } else {
        riskLevel = 'Low';
        riskColor = Colors.green;
      }

      final Map<String, int> crimeCounts = {};

      for (var crime in data) {
        final category = crime['category'];

        crimeCounts[category] =
            (crimeCounts[category] ?? 0) + 1;
      }

      mostCommonCrime = crimeCounts.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;

          topCrimeTypes = crimeCounts.entries.toList();

topCrimeTypes.sort(
  (a, b) => b.value.compareTo(a.value),
);

topCrimeTypes = topCrimeTypes.take(3).toList();

      errorMessage = '';
      isLoading = false;
    });
    } catch (e) {
      print(e);

      setState(() {
        errorMessage = e.toString();
        crimes = [];
        crimeFilters = ['All Crimes'];
        selectedCrimeFilter = 'All Crimes';
        isLoading = false;
      });
    }
  }
  String getCrimeIcon(String? category) {
    switch (category) {
      case 'anti-social-behaviour':
        return '🚨';

      case 'burglary':
        return '🏠';

      case 'vehicle-crime':
        return '🚗';

      case 'violent-crime':
        return '👊';

      case 'criminal-damage-arson':
        return '🔥';

      case 'shoplifting':
        return '🛒';

      case 'drugs':
        return '💊';

      default:
        return '🚔';
    }
  }

  Color getCrimeColor(String? category) {
  switch (category) {
    case 'violent-crime':
      return Colors.red;

    case 'burglary':
      return Colors.orange;

    case 'vehicle-crime':
      return Colors.blue;

    case 'drug':
      return Colors.purple;

    case 'criminal-damage-arson':
      return Colors.deepOrange;

    case 'shoplifting':
      return const Color.fromARGB(255, 243, 65, 6);

    case 'anti-social-behaviour':
      return const Color.fromARGB(255, 8, 142, 71);

    default:
      return Colors.grey;
  }
}

  String formatCrimeCategory(String category) {
    return category
        .replaceAll('-', ' ')
        .split(' ')
        .map(
          (word) =>
      word.isEmpty
          ? word
          : word[0].toUpperCase() + word.substring(1),
    )
        .join(' ');
  }

@override
void initState() {
  super.initState();

  pulseController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  );

pulseAnimation = Tween<double>(
  begin: 1.0,
  end: 1.3,
).animate(pulseController);

pulseController.repeat(reverse: true);

}

@override
void dispose() {
  pulseController.dispose();
  super.dispose();
}

Future<void> reportBug() async {
  final Uri emailUri = Uri(
    scheme: 'mailto',
    path: 'app1.f4mi1y@gmail.com',
    queryParameters: {
      'subject': 'Crime Watch Bug Report',
      'body': '''
Postcode:
Device:
Issue:

''',
    },
  );

  if (await canLaunchUrl(emailUri)) {
    await launchUrl(emailUri);
  }
}

Future<void> suggestFeature() async {
  final Uri emailUri = Uri.parse(
    'mailto:app1.f4mi1y@gmail.com'
    '?subject=Crime%20Watch%20Feature%20Request'
    '&body=Feature%20idea:%0A%0AWhy%20would%20it%20help?%0A%0A',
  );

  await launchUrl(emailUri);
}

Future<void> showPrivacyPolicy() async {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Privacy Policy'),
      content: const SingleChildScrollView(
        child: Text(
          'Crime Watch UK does not collect personal information. '
          'Crime data is provided by the UK Police Data API. '
          'Feedback submitted through email is only used to improve the app. '
          'Location data is only used to search the postcode entered by the user.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

Future<void> showTermsAndConditions() async {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Terms & Conditions'),
      content: const SingleChildScrollView(
        child: Text(
          'Crime Watch UK provides publicly available crime data '
          'from the UK Police Data API. Information is provided for '
          'general information purposes only and should not be relied '
          'upon as legal or safety advice. Users are responsible for '
          'their own decisions and actions.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

  @override
  Widget build(BuildContext context) {

    List filteredCrimes = selectedCrimeFilter == 'All Crimes'
        ? crimes
        : crimes.where((crime) {
      return crime['category'] == selectedCrimeFilter;
    }).toList();
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
       backgroundColor: const Color(0xFFF5F7FA),
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          controller: scrollController,
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),

           const Text(
  'Crime Watch UK',
  style: TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.bold,
    color: Colors.black87,
  ),
),

const SizedBox(height: 12),

const Text(
  'Discover local crime trends, safety insights and police data across the UK.',
  style: TextStyle(
    fontSize: 18,
    height: 1.4,
    color: Colors.black54,
  ),
),

const SizedBox(height: 20),

Container(
  padding: const EdgeInsets.all(14),
  decoration: BoxDecoration(
    color: Colors.blueGrey.shade50,
    borderRadius: BorderRadius.circular(12),
  ),
  child: const Row(
    children: [
      Icon(
        Icons.security,
        color: Colors.green,
      ),
      SizedBox(width: 10),
      Expanded(
        child: Text(
          'Search any UK postcode to view recent crime data and local safety insights.',
        ),
      ),
    ],
  ),
),

            const SizedBox(height: 30),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
  controller: postcodeController,
  textCapitalization: TextCapitalization.characters,
  maxLength: 8,

onChanged: (value) {
  postcodeController.value = TextEditingValue(
    text: value.toUpperCase(),
    selection: TextSelection.collapsed(
      offset: value.length,
    ),
  );
},

  decoration: InputDecoration(
    hintText: 'Enter UK postcode',
    border: OutlineInputBorder(),
    prefixIcon: Icon(Icons.location_on),
    counterText: '',
  ),
),
            ),
            const SizedBox(height: 20),

            SizedBox(

              width: double.infinity,
              child: ElevatedButton(
               onPressed: () async {
  searchedPostcode = postcodeController.text.trim().toUpperCase();

 if (!recentSearches.contains(searchedPostcode)) {
    recentSearches.insert(0, searchedPostcode);

    if (recentSearches.length > 5) {
      recentSearches.removeLast();
    }
  }

  print('ABOUT TO CALL FETCH'); 
  await fetchCrimeData();

  setState(() {});
},
                child: const Text('Search Area'),
              ),
            ),

        const SizedBox(height: 30),

            if (searchedLatitude != null && searchedLongitude != null)
  Container(
    height: 350,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
      color: Colors.blueGrey,
      width: 2,
),
      boxShadow: [
        BoxShadow(
          color: Colors.black12,
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ],
    ),
    clipBehavior: Clip.hardEdge,
    child: FlutterMap(
                  mapController: mapController,
                  options: MapOptions(
                    initialCenter: LatLng(
                      searchedLatitude!,
                      searchedLongitude!,
                    ),
                    initialZoom: 15,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.crime_watch_app',
                    ),
                    MarkerLayer(
                      markers: [

Marker(
  point: LatLng(
    searchedLatitude!,
    searchedLongitude!,
  ),
  width: 50,
  height: 50,
  child: AnimatedBuilder(
    animation: pulseAnimation,
    builder: (context, child) {
      return Transform.scale(
        scale: pulseAnimation.value,
        child: child,
      );
    },
    child: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.blue,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white,
          width: 3,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 6,
          ),
        ],
      ),
      child: const Icon(
        Icons.person,
        color: Colors.white,
        size: 24,
      ),
    ),
  ),
),
                        ...filteredCrimes
                            .where((crime) {
                          final location = crime['location'];

                          return location is Map &&
                              location['latitude'] != null &&
                              location['longitude'] != null;
                        })
                            .map((crime) {
                          print(crime);
                          return Marker(
                            point: LatLng(
                              double.parse(crime['location']['latitude']),
                              double.parse(crime['location']['longitude']),
                            ),
      width: 30,
      height: 30,
     child: GestureDetector(
  onTap: () {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            formatCrimeCategory(
              crime['category'] ?? 'Unknown',
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '📍 ${crime['location']['street']['name']}',
              ),

              const SizedBox(height: 8),

              Text(
                '📅 ${crime['month']}',
              ),

              const SizedBox(height: 8),

              Text(
                '📋 ${crime['outcome_status']?['category'] ?? 'No outcome available'}',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  },
 child: Container(
  width: 30,
  height: 30,
  decoration: BoxDecoration(
    color: getCrimeColor(
      crime['category'],
    ),
    shape: BoxShape.circle,
    boxShadow: [
      BoxShadow(
        color: Colors.black26,
        blurRadius: 4,
      ),
    ],
  ),
  child: Center(
    child: Text(
      getCrimeIcon(
        crime['category'],
      ),
      style: const TextStyle(
        fontSize: 14,
      ),
    ),
  ),
),
),
      );
                    }),

                        Marker(
                          point: LatLng(
                            searchedLatitude!,
                            searchedLongitude!,
                          ),
                          width: 50,
                          height: 50,
                         child: Container(
  width: 40,
  height: 40,
  decoration: BoxDecoration(
    color: Colors.blue,
    shape: BoxShape.circle,
    border: Border.all(
      color: Colors.white,
      width: 3,
    ),
    boxShadow: const [
      BoxShadow(
        color: Colors.black26,
        blurRadius: 6,
      ),
    ],
  ),
  child: const Icon(
    Icons.person,
    color: Colors.white,
    size: 24,
  ),
),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            if (isLoading)
              const Center(
                child: CircularProgressIndicator(),
              ),

              Text(
                'Searching area: $searchedPostcode',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

            if (errorMessage.isNotEmpty)
              Text(
                errorMessage,
                style: const TextStyle(
                  fontSize: 16,
                ),
              ),

            const SizedBox(height: 20),

           Row(
  children: [
    Expanded(
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
              Icon(Icons.warning_amber_rounded),
              SizedBox(height: 8),
              Text(
                '${crimes.length}',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text('Total Crimes'),
            ],
          ),
        ),
      ),
    ),

    SizedBox(width: 12),

    Expanded(
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
              Icon(Icons.location_on),
              SizedBox(height: 8),
              Text(
                searchedPostcode,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text('Area'),
            ],
          ),
        ),
      ),
    ),
  ],
),
            
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Area Summary',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Container(
  width: double.infinity,
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: riskColor.withOpacity(0.1),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(
      color: riskColor,
      width: 2,
    ),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '$riskLevel Risk Area',
        style: TextStyle(
          color: riskColor,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),

      const SizedBox(height: 12),

      Text('📍 Postcode: $searchedPostcode'),
      Text('🚨 Crimes Reported: ${crimes.length}'),
      Text('📊 Crime Categories: $crimeTypesCount'),
      Text('🔥 Most Common Crime: $mostCommonCrime'),
      Text('📅 Latest Data: $latestCrimeMonth'),

const SizedBox(height: 12),

Text(
  '⭐ Safety Score: ${riskLevel == 'Low' ? '8/10' : riskLevel == 'Medium' ? '5/10' : '2/10'}',
  style: const TextStyle(
    fontWeight: FontWeight.bold,
  ),
),

const SizedBox(height: 16),

const Text(
  'Top Crime Types',
  style: TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
  ),
),

const SizedBox(height: 8),

if (topCrimeTypes.isNotEmpty)
  Text(
    '🥇 ${formatCrimeCategory(topCrimeTypes[0].key)} (${topCrimeTypes[0].value})',
  ),

if (topCrimeTypes.length > 1)
  Text(
    '🥈 ${formatCrimeCategory(topCrimeTypes[1].key)} (${topCrimeTypes[1].value})',
  ),

if (topCrimeTypes.length > 2)
  Text(
    '🥉 ${formatCrimeCategory(topCrimeTypes[2].key)} (${topCrimeTypes[2].value})',
  ),

    ],
  ),
),

const SizedBox(height: 16),

const Text(
  'Filter Crimes',
  style: TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
  ),
),
const SizedBox(height: 8),

                    Container(
  padding: const EdgeInsets.symmetric(
    horizontal: 16,
  ),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: Colors.grey.shade300,
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black12,
        blurRadius: 6,
        offset: Offset(0, 2),
      ),
    ],
  ),
  child: DropdownButton<String>(
    value: selectedCrimeFilter,
    isExpanded: true,
    underline: const SizedBox(),
    icon: const Icon(Icons.filter_list),
    items: crimeFilters.map((filter) {
      return DropdownMenuItem<String>(
        value: filter,
        child: Text(
          filter == 'All Crimes'
              ? filter
              : formatCrimeCategory(filter),
        ),
      );
    }).toList(),
    onChanged: (value) {
      setState(() {
        selectedCrimeFilter = value!;

        if (value == 'All Crimes') {
          filteredCrimes = crimes;
        } else {
          filteredCrimes = crimes.where((crime) {
            return crime['category'] == value;
          }).toList();
        }
      });
    },
  ),
)
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            const SizedBox(height: 20),

    ListView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: filteredCrimes.length,
    itemBuilder: (context, index) {
    final crime = filteredCrimes[index];

                  return Card(
                      child: ListTile(
                        title: Text(
                          getCrimeIcon(crime['category']) +
                              ' ' +
                              formatCrimeCategory(
                                crime['category'] ?? 'Unknown',
                              ),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '📍 ${crime['location']['street']['name']}',
                            ),

                            const SizedBox(height: 4),

                            Text(
                              '📅 ${crime['month']}',
                            ),

                            Text(
                              '📋 ${crime['outcome_status']?['category'] ?? 'No outcome available'}',
                            ),
                                              ],
    
                  ),
                ),
              );
    },
    ),

if (recentSearches.isNotEmpty)
  Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Searches',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          ...recentSearches.map(
  (postcode) => ListTile(
    leading: const Icon(Icons.history),
    title: Text(postcode),
    trailing: const Icon(Icons.arrow_forward_ios, size: 16),

    onTap: () async {
  postcodeController.text = postcode;
  searchedPostcode = postcode;

  await fetchCrimeData();

  scrollController.animateTo(
    0,
    duration: const Duration(milliseconds: 600),
    curve: Curves.easeInOut,
  );

  setState(() {});
},
  ),
),
        ],
      ),
    ),
  ),

const SizedBox(height: 24),

Card(
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        const Text(
          'Support & Feedback',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 12),

        ListTile(
  leading: const Icon(Icons.bug_report),
  title: const Text('Report a Bug'),
  subtitle: const Text(
    'Tell us about an issue you found',
  ),
  onTap: reportBug,
),

        ListTile(
  leading: const Icon(Icons.lightbulb),
  title: const Text('Suggest a Feature'),
  subtitle: const Text(
    'Share an idea for improving Crime Watch',
  ),
  onTap: suggestFeature,
),

ListTile(
  leading: const Icon(Icons.privacy_tip),
  title: const Text('Privacy Policy'),
  onTap: showPrivacyPolicy,
),

ListTile(
  leading: const Icon(Icons.description),
  title: const Text('Terms & Conditions'),
  onTap: showTermsAndConditions,
),

        const Divider(),

        const Text(
          'Crime Watch UK v1.0',
          style: TextStyle(
            color: Colors.grey,
          ),
        ),
      ],
    ),
  ),
),

          ],
      ),
    ),
      ),
  );
}
}