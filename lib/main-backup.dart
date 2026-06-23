import 'package:flutter/material.dart';
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
        colorScheme: .fromSeed(seedColor: Colors.blueGrey),
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

  double? searchedLatitude;
  double? searchedLongitude;

  late AnimationController pulseController;
  late Animation<double> pulseAnimation;
  bool clusteringEnabled = true;

  final MapController mapController = MapController();

  String selectedCrimeFilter = 'All Crimes';
  List<String> crimeFilters = ['All Crimes'];
  List filteredCrimes = [];
  bool isLoading = false;
  String errorMessage = '';
  int crimeTypesCount = 0;
  String latestCrimeMonth = '';
  String mostCommonCrime = '';
  String riskLevel = '';

  Color riskColor = Colors.green;

  Future<Map<String, dynamic>?> getCoordinatesFromPostcode() async {
    final postcodeUrl = Uri.parse(
      'https://api.postcodes.io/postcodes/${postcodeController.text}',
    );

    final response = await http.get(postcodeUrl);

    final data = jsonDecode(response.body);

    print(data);

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

    mapController.move(
      LatLng(latitude, longitude),
      15,
    );

    final url = Uri.parse(
      'https://data.police.uk/api/crimes-street/all-crime?lat=$latitude&lng=$longitude',);

    final response = await http.get(url);

    final data = jsonDecode(response.body);

     print(data);

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
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
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
              child: TextField(controller: postcodeController,
                decoration: InputDecoration(
                  hintText: 'Enter UK postcode',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(

              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  setState(() {
                    searchedPostcode = postcodeController.text;
                  });

                  await fetchCrimeData();
                },
                child: const Text('Search Area'),
              ),
            ),

        const SizedBox(height: 30),

            if (searchedLatitude != null && searchedLongitude != null)
              SizedBox(
                height: 350,
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

            Text(
              'Crime found: $crimeCategory',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            Text(
              'Total crimes found: ${crimes.length}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
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
    ],
  ),
),

                    DropdownButton<String>(
                      value: selectedCrimeFilter,
                      isExpanded: true,
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
          ],
        ),
      ),
      ),
    );
  }
}
