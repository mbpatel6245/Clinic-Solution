import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/locale_key.dart';
import '../../../../data/datasources/stock_model.dart';
import '../../../../services/firestore_services.dart';

class StockInwardViewmodel with ChangeNotifier {
  // Text Editing Controllers
  final TextEditingController billNoCnt = TextEditingController();
  final TextEditingController shortNameCnt = TextEditingController();
  final TextEditingController manufacturerCnt = TextEditingController();
  TextEditingController expiryDateController = TextEditingController();
  final TextEditingController minAvailCnt = TextEditingController();
  final TextEditingController maxAvailCnt = TextEditingController();
  TextEditingController nearestDurationDayController = TextEditingController();
  TextEditingController brandNameCnt = TextEditingController();
  TextEditingController purchasePersonCnt = TextEditingController();
  TextEditingController containsMedicineCnt = TextEditingController();
  TextEditingController dateOfPurchaseController = TextEditingController();
  TextEditingController quntMedicineCnt = TextEditingController();
  TextEditingController quntTabletCnt = TextEditingController();
  TextEditingController quntBoxCnt = TextEditingController();
  TextEditingController formTypeCnt = TextEditingController();
  TextEditingController colorContentCnt = TextEditingController();
  String stockVisibility = Constants.show;

  //String typeOfStock = Constants.medicine;
  final FirebaseFireStore _fireStoreService = FirebaseFireStore();
  List<Widget> powerOfSizeWidgetList = [];
  List<TextEditingController> posNameListController = [];
  List<TextEditingController> posSizeListController = [];

  // List of roles for the dropdown
  final List<String> visibilityList = [Constants.show, Constants.hide];

  final Stream<QuerySnapshot> stockStream = FirebaseFirestore.instance
      .collection(FirebaseFireStore.pathStock)
      .snapshots();

  void onVisibilityChanged(String? value) {
    stockVisibility = value ?? Constants.show;
    notifyListeners();
  }

  List<String> getListOfTextEditController(List<TextEditingController> list) {
    return list.map((controller) => controller.text).toList();
  }

  bool validateForm(GlobalKey<FormState> formKey) {
    return formKey.currentState?.validate() ?? false;
  }

  String getPowerOfSizeJsonData(
      List<TextEditingController> powerOfSizeContentListOfController,
      List<TextEditingController> powerOfSizeListController) {
    if (powerOfSizeContentListOfController.length !=
        powerOfSizeListController.length) {
      print(
          "Error: Both list for Power of size must have the same number of items.");
      return "";
    }

    List<Map<String, String>> jsonList = [];

    for (int i = 0; i < powerOfSizeContentListOfController.length; i++) {
      String contentName = powerOfSizeListController[i].text;
      String size = powerOfSizeContentListOfController[i].text;

      jsonList.add({
        "contentName": contentName,
        "size": size,
      });
    }

    return jsonEncode(jsonList);
  }

  Future<void> updateStockData(String typeOfStock, String docId,
      Function successCallback, Function errorCallback) async {
    try {
     await _fireStoreService.updateStock(
          StockModel(
              typeOfStock: typeOfStock,
              billNumber: billNoCnt.text,
              shortName: shortNameCnt.text,
              manufacturerName: manufacturerCnt.text,
              expiryDate: expiryDateController.text,
              visibility: stockVisibility,
              minimumAvailability: minAvailCnt.text,
              maximumAvailability: maxAvailCnt.text,
              nearestDurationDay: nearestDurationDayController.text,
              brandName: brandNameCnt.text,
              purchasingPerson: purchasePersonCnt.text,
              containsMedicine: containsMedicineCnt.text,
              dateOfPurchase: dateOfPurchaseController.text,
              quantityMedicine: quntMedicineCnt.text,
              quantityBox: quntBoxCnt.text,
              quantityTablets: quntTabletCnt.text,
              formType: formTypeCnt.text,
              colorOfContent: colorContentCnt.text,
              posContentSize:
                  getListOfTextEditController(posSizeListController),
              posContentName:
                  getListOfTextEditController(posNameListController)),
          docId,
          successCallback,
          errorCallback);
      clearData();
      clearPowerOfSize();
    } catch (e,stack) {
      print(stack.toString());
      print('Error saving data: $e');
    }
  }

  Future<void> addNewStockData(String typeOfStock, Function successCallback,
      Function errorCallback) async {
    try {
      await _fireStoreService.addNewStock(
          StockModel(
              typeOfStock: typeOfStock,
              billNumber: billNoCnt.text,
              shortName: shortNameCnt.text,
              manufacturerName: manufacturerCnt.text,
              expiryDate: expiryDateController.text,
              visibility: stockVisibility,
              minimumAvailability: minAvailCnt.text,
              maximumAvailability: maxAvailCnt.text,
              nearestDurationDay: nearestDurationDayController.text,
              brandName: brandNameCnt.text,
              purchasingPerson: purchasePersonCnt.text,
              containsMedicine: containsMedicineCnt.text,
              dateOfPurchase: dateOfPurchaseController.text,
              quantityMedicine: quntMedicineCnt.text,
              quantityBox: quntBoxCnt.text,
              quantityTablets: quntTabletCnt.text,
              formType: formTypeCnt.text,
              colorOfContent: colorContentCnt.text,
              posContentSize:
                  getListOfTextEditController(posSizeListController),
              posContentName:
                  getListOfTextEditController(posNameListController)),
          successCallback,
          errorCallback);
      clearData();
      clearPowerOfSize();
    } catch (e) {
      print('Error saving data: $e');
    }
  }

  Future<void> deleteStockData(String stockDocumentId) async {
    try {
      _fireStoreService.deleteStock(stockDocumentId);
    } catch (e) {
      print('Error deleting stock: $e');
    }
  }

  void clearPowerOfSize() {
    powerOfSizeWidgetList.clear();
    posNameListController.clear();
    posSizeListController.clear();
  }

  void clearData() {
    stockVisibility = Constants.show;
    billNoCnt.text = "";
    shortNameCnt.text = "";
    manufacturerCnt.text = "";
    expiryDateController.text = "";
    minAvailCnt.text = "";
    maxAvailCnt.text = "";
    nearestDurationDayController.text = "";
    brandNameCnt.text = "";
    purchasePersonCnt.text = "";
    containsMedicineCnt.text = "";
    dateOfPurchaseController.text = "";
    quntMedicineCnt.text = "";
    quntBoxCnt.text = "";
    quntTabletCnt.text = "";
    formTypeCnt.text = "";
    colorContentCnt.text = "";
  }

  // Dispose controllers
  @override
  void dispose() {
    billNoCnt.dispose();
    shortNameCnt.dispose();
    manufacturerCnt.dispose();
    expiryDateController.dispose();
    minAvailCnt.dispose();
    maxAvailCnt.dispose();
    nearestDurationDayController.dispose();
    brandNameCnt.dispose();
    purchasePersonCnt.dispose();
    containsMedicineCnt.dispose();
    dateOfPurchaseController.dispose();
    quntMedicineCnt.dispose();
    quntBoxCnt.dispose();
    quntTabletCnt.dispose();
    formTypeCnt.dispose();
    colorContentCnt.dispose();

    super.dispose();
  }

  Future<void> selectDate(
      BuildContext context, TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      // If a date is picked, format it and set it in the TextField
      //setState(() {
      controller.text = DateFormat('yyyy-MM-dd').format(picked);
      //});
    }
  }
}
