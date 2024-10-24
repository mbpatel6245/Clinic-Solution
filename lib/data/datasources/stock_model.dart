import 'package:cloud_firestore/cloud_firestore.dart';

class StockModel {
  String? typeOfStock;
  String? billNumber;
  String? shortName;
  String? manufacturerName;
  String? expiryDate;
  String? minimumAvailability;
  String? maximumAvailability;
  String? nearestDurationDay;
  String? brandName;
  String? purchasingPerson;
  String? containsMedicine;
  String? dateOfPurchase;
  String? quantityMedicine;
  String? quantityTablets;
  String? quantityBox;
  final List<String>? posContentName;
  final List<String>? posContentSize;
  String? formType;
  String? colorOfContent;
  String? visibility;

  StockModel(
      {this.typeOfStock,
      this.billNumber,
      this.shortName,
      this.manufacturerName,
      this.expiryDate,
      this.minimumAvailability,
      this.maximumAvailability,
      this.nearestDurationDay,
      this.brandName,
      this.purchasingPerson,
      this.containsMedicine,
      this.dateOfPurchase,
      this.quantityMedicine,
      this.quantityTablets,
      this.quantityBox,
      this.posContentName,
      this.posContentSize,
      this.formType,
      this.colorOfContent,
      this.visibility});

  factory StockModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    final data = snapshot.data();
    return StockModel(
        typeOfStock: data?['type_of_stock'],
        billNumber: data?['bill_number'],
        shortName: data?['short_name'],
        manufacturerName: data?['manufacturer_name'],
        expiryDate: data?['expiry_date'],
        minimumAvailability: data?['minimum_availability'],
        maximumAvailability: data?['maximum_availability'],
        nearestDurationDay: data?['nearest_duration_day'],
        brandName: data?['brand_name'],
        purchasingPerson: data?['purchasing_person'],
        containsMedicine: data?['contains_medicine'],
        dateOfPurchase: data?['date_of_purchase'],
        quantityMedicine: data?['quantity_medicine'],
        quantityTablets: data?['quantity_tablets'],
        quantityBox: data?['quantity_box'],
        posContentName: data?['pos_content_name'] is Iterable
            ? List.from(data?['pos_content_name'])
            : null,
        posContentSize: data?['pos_content_size'] is Iterable
            ? List.from(data?['pos_content_size'])
            : null,
        formType: data?['form_type'],
        colorOfContent: data?['color_of_content'],
        visibility: data?['visibility']);
  }

  Map<String, dynamic> toFirestore() {
    return {
      if (typeOfStock != null) 'type_of_stock': typeOfStock,
      if (billNumber != null) 'bill_number': billNumber,
      if (shortName != null) 'short_name': shortName,
      if (manufacturerName != null) 'manufacturer_name': manufacturerName,
      if (expiryDate != null) 'expiry_date': expiryDate,
      if (minimumAvailability != null)
        'minimum_availability': minimumAvailability,
      if (maximumAvailability != null)
        'maximum_availability': maximumAvailability,
      if (nearestDurationDay != null)
        'nearest_duration_day': nearestDurationDay,
      if (brandName != null) 'brand_name': brandName,
      if (purchasingPerson != null) 'purchasing_person': purchasingPerson,
      if (containsMedicine != null) 'contains_medicine': containsMedicine,
      if (dateOfPurchase != null) 'date_of_purchase': dateOfPurchase,
      if (quantityMedicine != null) 'quantity_medicine': quantityMedicine,
      if (quantityTablets != null) 'quantity_tablets': quantityTablets,
      if (quantityBox != null) 'quantity_box': quantityBox,
      if (posContentName != null) 'pos_content_name': posContentName,
      if (posContentSize != null) 'pos_content_size': posContentSize,
      if (formType != null) 'form_type': formType,
      if (colorOfContent != null) 'color_of_content': colorOfContent,
      if (visibility != null) 'visibility': visibility
    };
  }
}
