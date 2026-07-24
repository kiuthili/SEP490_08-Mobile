import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  final token = 'pk.eyJ1IjoicGhhbWtoYXZ5MTEwMiIsImEiOiJjbWZxdzRyOGcwMzU0MmlwYXozdG5zdjI0In0.TF-jItzlzC3i-LLE4sepEA';
  final url = 'https://api.mapbox.com/styles/v1/mapbox/streets-v11/tiles/256/1/0/0@2x?access_token=$token';
  print('Fetching: $url');
  
  try {
    final response = await http.get(Uri.parse(url));
    print('Status Code: ${response.statusCode}');
    print('Headers: ${response.headers}');
    if (response.statusCode != 200) {
      print('Body: ${response.body}');
    } else {
      print('Body bytes length: ${response.bodyBytes.length}');
      print('Content-Type: ${response.headers['content-type']}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
