import 'dart:convert';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';

class CredentialAttachment {
  final String name;
  final Uint8List bytes;

  CredentialAttachment({required this.name, required this.bytes});

  Map<String, dynamic> toJson() => {
        'name': name,
        'bytes': base64Encode(bytes),
      };

  factory CredentialAttachment.fromJson(Map<String, dynamic> json) {
    return CredentialAttachment(
      name: json['name'] as String,
      bytes: base64Decode(json['bytes'] as String),
    );
  }
}

class CredentialEntry {
  final String id;
  final String title;
  final String username;
  final String password;
  final String websiteUrl;
  final String websiteIconUrl;
  final String notes;
  final String category;
  final Map<String, String> customFields;
  final List<CredentialAttachment> attachments;
  final bool isFavorite;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;

  CredentialEntry({
    String? id,
    required this.title,
    required this.username,
    required this.password,
    this.websiteUrl = '',
    this.websiteIconUrl = '',
    this.notes = '',
    this.category = 'General',
    Map<String, String>? customFields,
    List<CredentialAttachment>? attachments,
    this.isFavorite = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.version = 1,
  })  : id = id ?? const Uuid().v4(),
        customFields = customFields ?? {},
        attachments = attachments ?? [],
        createdAt = createdAt ?? DateTime.now().toUtc(),
        updatedAt = updatedAt ?? DateTime.now().toUtc();

  CredentialEntry copyWith({
    String? title,
    String? username,
    String? password,
    String? websiteUrl,
    String? websiteIconUrl,
    String? notes,
    String? category,
    Map<String, String>? customFields,
    List<CredentialAttachment>? attachments,
    bool? isFavorite,
    int? version,
  }) {
    return CredentialEntry(
      id: id,
      title: title ?? this.title,
      username: username ?? this.username,
      password: password ?? this.password,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      websiteIconUrl: websiteIconUrl ?? this.websiteIconUrl,
      notes: notes ?? this.notes,
      category: category ?? this.category,
      customFields: customFields ?? Map.from(this.customFields),
      attachments: attachments ?? List.from(this.attachments),
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt,
      updatedAt: DateTime.now().toUtc(),
      version: version ?? (this.version + 1),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'username': username,
    'password': password,
    'websiteUrl': websiteUrl,
    'websiteIconUrl': websiteIconUrl,
    'notes': notes,
    'category': category,
    'customFields': customFields,
    'attachments': attachments.map((attachment) => attachment.toJson()).toList(),
    'isFavorite': isFavorite,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'version': version,
  };

  factory CredentialEntry.fromJson(Map<String, dynamic> json) {
    return CredentialEntry(
      id: json['id'] as String,
      title: json['title'] as String,
      username: json['username'] as String,
      password: json['password'] as String,
      websiteUrl: json['websiteUrl'] as String? ?? '',
      websiteIconUrl: json['websiteIconUrl'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      category: json['category'] as String? ?? 'General',
      customFields: (json['customFields'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v.toString()),
          ) ?? {},
      attachments: (json['attachments'] as List<dynamic>?)
              ?.map(
                (item) => CredentialAttachment.fromJson(
                  item as Map<String, dynamic>,
                ),
              )
              .toList() ??
          [],
      isFavorite: json['isFavorite'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      version: json['version'] as int? ?? 1,
    );
  }
}