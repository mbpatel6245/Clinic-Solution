import 'package:clinic_solution/ui/views/home/stock_inward/stock_inward_viewmodel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:clinic_solution/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/locale_key.dart';
import '../../../../core/utils/locale_provider.dart';
import '../../../../data/datasources/stock_model.dart';
import '../../../../services/firestore_services.dart';
import '../../../themes/text_styles.dart';
import '../../../widgets/common_text.dart';
import '../../../widgets/common_textfield.dart';

typedef StockSelectionCallback = void Function(
    String selectedValue, String selectedDocId, StockModel selectedItem);

class ListOfStocks extends StatefulWidget {
  final StockSelectionCallback onStockSelected;

  ListOfStocks({super.key, required this.onStockSelected});

  @override
  State<ListOfStocks> createState() => _ListOfStocksState();
}

class _ListOfStocksState extends State<ListOfStocks> {
  final TextEditingController searchStockController = TextEditingController();
  late Stream<QuerySnapshot> stockStream;
  var localeProvider = LocaleProvider();

  @override
  void initState() {
    super.initState();
    // Initial query to load all stocks
    stockStream = FirebaseFirestore.instance
        .collection(FirebaseFireStore.pathStock)
        .snapshots();

    // Listen for changes in the search input and update the stream
    searchStockController.addListener(() {
      setState(() {
        stockStream = FirebaseFirestore.instance
            .collection(FirebaseFireStore.pathStock)
            .snapshots();
      });
    });
  }

  @override
  void dispose() {
    searchStockController.dispose();
    super.dispose();
  }

  void handleSelection(String value, String docId, StockModel item) {
    widget.onStockSelected(value, docId, item); // Call the combined callback
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
        create: (_) => StockInwardViewmodel(),
        child: Consumer<StockInwardViewmodel>(
            builder: (context, viewModel, child) {
          return Column(
            children: [
              // Center(
              //     child: CommonText(
              //   text: AppLocalizations.of(context)!.listOfStockData,
              //   color: Colors.red,
              //   height: getSize(35),
              // )),
              Padding(
                padding: const EdgeInsets.only(left: 10, right: 10),
                child: CommonTextField(
                  controller: searchStockController,
                  keyboardType: TextInputType.text,
                  hintText: "",
                  labelText: AppLocalizations.of(context)!.searchStock,
                  prefixIcon: Icons.search,
                  suffixIcon: (searchStockController.text.isEmpty == true)
                      ? null
                      : Icons.close,
                  suffixOnTap: () {
                    searchStockController.clear();
                  },
                  //validator: Validator().validatePhone,
                ),
              ),
              const SizedBox(height: 15.0),
              Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                stream: stockStream,
                builder: (BuildContext context,
                    AsyncSnapshot<QuerySnapshot> snapshot) {
                  if (snapshot.hasError) {
                    return CommonText(
                      text: "Something went wrong!",
                      style: AppTextStyles.getBoldTextStyle(
                              localeProvider.locale,
                              fontSize: 16)
                          .copyWith(color: Colors.deepOrange),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return CommonText(
                      text: "Loading...",
                      style: AppTextStyles.getBoldTextStyle(
                              localeProvider.locale,
                              fontSize: 16)
                          .copyWith(color: Colors.lightBlue),
                    );
                  }

                  // Filter results locally based on multiple fields
                  final searchTerm =
                      searchStockController.text.trim().toLowerCase();
                  final documents = snapshot.data?.docs.where((document) {
                    final stockData = document.data() as Map<String, dynamic>;

                    // Check each field for a match
                    return (stockData['brand_name'] as String?)
                                ?.toLowerCase()
                                .contains(searchTerm) ==
                            true ||
                        (stockData['contains_medicine'] as String?)
                                ?.toLowerCase()
                                .contains(searchTerm) ==
                            true ||
                        (stockData['purchasing_person'] as String?)
                                ?.toLowerCase()
                                .contains(searchTerm) ==
                            true ||
                        (stockData['manufacturer_name'] as String?)
                                ?.toLowerCase()
                                .contains(searchTerm) ==
                            true ||
                        (stockData['short_name'] as String?)
                                ?.toLowerCase()
                                .contains(searchTerm) ==
                            true ||
                        (stockData['bill_number'] as String?)
                                ?.toLowerCase()
                                .contains(searchTerm) ==
                            true;
                  }).toList();

                  if (documents?.isEmpty == true) {
                    return CommonText(
                      text: "Stock not found!",
                      style: AppTextStyles.getBoldTextStyle(
                              localeProvider.locale,
                              fontSize: 16)
                          .copyWith(color: Colors.deepOrange),
                    );
                  }
                  return ListView(
                    children: documents!.map((DocumentSnapshot document) {
                      StockModel stock = StockModel.fromFirestore(
                          document as DocumentSnapshot<Map<String, dynamic>>,
                          null);
                      return stockListItem(stock, viewModel, context, document);
                    }).toList(),
                  );
                },
              ))
            ],
          );
        }));
  }

  Card stockListItem(StockModel stock, StockInwardViewmodel viewModel,
      BuildContext context, DocumentSnapshot<Map<String, dynamic>> document) {
    //var localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 10.0),
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Table(
                    columnWidths: const {
                      0: FlexColumnWidth(1),
                      1: FlexColumnWidth(1),
                    },
                    children: [
                      // First Row with multiple columns
                      TableRow(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CommonText(
                                text: AppLocalizations.of(context)!.shortName,
                                style: AppTextStyles.getBoldTextStyle(
                                  localeProvider.locale,
                                  fontSize: 14,
                                ),
                              ),
                              CommonText(
                                text: (stock.shortName ?? '').toUpperCase(),
                                style: AppTextStyles.getRegularTextStyle(
                                  localeProvider.locale,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CommonText(
                                text: AppLocalizations.of(context)!.containsOfMedicine,
                                style: AppTextStyles.getBoldTextStyle(
                                  localeProvider.locale,
                                  fontSize: 14,
                                ),
                              ),
                              CommonText(
                                text: stock.containsMedicine ?? '',
                                style: AppTextStyles.getRegularTextStyle(
                                  localeProvider.locale,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CommonText(
                                text: AppLocalizations.of(context)!.brandName,
                                style: AppTextStyles.getBoldTextStyle(
                                  localeProvider.locale,
                                  fontSize: 14,
                                ),
                              ),
                              CommonText(
                                text: stock.brandName ?? '',
                                style: AppTextStyles.getRegularTextStyle(
                                  localeProvider.locale,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),

                        ],
                      ),
                      // Third row for Availability and Quantity
                      TableRow(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CommonText(
                                text: AppLocalizations.of(context)!.quantity,
                                style: AppTextStyles.getBoldTextStyle(
                                  localeProvider.locale,
                                  fontSize: 14,
                                ),
                              ),
                              CommonText(
                                text:
                                '${stock.quantityMedicine ?? '0'} Medicines | ${stock.quantityTablets ?? '0'} Tablets | ${stock.quantityBox ?? '0'} Boxes',
                                style: AppTextStyles.getRegularTextStyle(
                                  localeProvider.locale,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CommonText(
                                text: AppLocalizations.of(context)!.purchasingPerson,
                                style: AppTextStyles.getBoldTextStyle(
                                  localeProvider.locale,
                                  fontSize: 14,
                                ),
                              ),
                              CommonText(
                                text:
                                stock.purchasingPerson??"",
                                style: AppTextStyles.getRegularTextStyle(
                                  localeProvider.locale,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CommonText(
                                text: AppLocalizations.of(context)!.expiryDate,
                                style: AppTextStyles.getBoldTextStyle(
                                  localeProvider.locale,
                                  fontSize: 14,
                                ),
                              ),
                              CommonText(
                                text: stock.expiryDate ?? '',
                                style: AppTextStyles.getRegularTextStyle(
                                  localeProvider.locale,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.lightBlue),
                      onPressed: () {
                        handleSelection(Constants.update, document.id, stock);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        viewModel.deleteStockData(document.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              AppLocalizations.of(context)!.stockDeletedSuccessfully,
                            ),
                          ),
                        );
                        handleSelection(Constants.delete, document.id, stock);
                      },
                    ),
                  ],
                ),
              ],
            ),
            //const Divider(),
            // Final Row for Purchase and Type
           /* Table(
              columnWidths: const {
                0: FlexColumnWidth(1),
                1: FlexColumnWidth(1),
              },
              children: [
                TableRow(
                  children: [
                    CommonText(
                      text: 'Purchased: ${stock.dateOfPurchase ?? 'Unknown'}',
                      style: AppTextStyles.getRegularTextStyle(
                        localeProvider.locale,
                        fontSize: 14,
                      ).copyWith(color: Colors.grey[600]),
                    ),
                    CommonText(
                      fontSize: 14,
                      text: stock.typeOfStock == Constants.medicine
                          ? Constants.medicine
                          : Constants.others,
                      color: stock.typeOfStock == Constants.medicine
                          ? Colors.green
                          : Colors.red,
                    ),
                  ],
                ),
              ],
            ),*/
          ],
        ),
      ),
    );
  }
}
