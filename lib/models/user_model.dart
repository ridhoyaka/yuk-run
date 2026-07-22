class User {
  final int id;
  final String nama;
  final String email;

  User({
    required this.id,
    required this.nama,
    required this.email,
  });

  // Fungsi untuk mengubah data JSON dari API Node.js menjadi objek Flutter
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0,
      nama: json['nama'] ?? 'Pelari',
      email: json['email'] ?? '',
    );
  }
}