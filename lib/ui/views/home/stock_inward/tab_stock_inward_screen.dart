import 'package:clinic_solution/core/utils/size_utils.dart';
import 'package:clinic_solution/ui/views/home/stock_inward/stock_inward_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/locale_key.dart';
import '../../../../data/datasources/stock_model.dart';
import 'list_of_stock_view.dart';
import 'manage_stock_item.dart';

class TabStockInward extends StatefulWidget {
  const TabStockInward({super.key});

  @override
  State<TabStockInward> createState() => _TabStockInwardState();
}

class _TabStockInwardState extends State<TabStockInward> {
  String? _listActionValue;
  String? _docId;
  StockModel? _selectedItem;

  void _handleValueCallback(String action, String docId, StockModel item) {
    setState(() {
      _listActionValue = action;
      _docId = docId;
      _selectedItem = item;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => StockInwardViewmodel(),
      child: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Center(
            child: Consumer<StockInwardViewmodel>(
              builder: (context, viewModel, child) {
                return isTabletOrDesktop(context)
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                              child: ListOfStocks(
                                  onStockSelected: _handleValueCallback)),
                          if (isManageStock())
                            const VerticalDivider(
                              color: Colors.grey,
                              thickness: 1, // Thickness of the divider
                              width: 20, // Space around the divider
                            ),
                          if (isManageStock())
                            Expanded(
                                child: ManageStockItem(
                                    actionValue: _listActionValue,
                                    stock: _selectedItem,
                                    docId: _docId ?? "", () {
                              _handleValueCallback("", "", StockModel());
                            })),
                        ],
                      )
                    : Column(
                        children: [
                          Expanded(
                              child: ListOfStocks(
                                  onStockSelected: _handleValueCallback)),
                          if (isManageStock()) const SizedBox(height: 15.0),
                          if (isManageStock()) const Divider(),
                          if (isManageStock()) const SizedBox(height: 15.0),
                          if (isManageStock())
                            Expanded(
                                child: ManageStockItem(
                                    actionValue: _listActionValue,
                                    stock: _selectedItem,
                                    docId: _docId ?? "", () {
                              _handleValueCallback("", "", StockModel());
                            })),
                        ],
                      );
              },
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            _handleValueCallback(Constants.add, "", StockModel());
          },
          tooltip: 'Add New Stock',
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          shape: const CircleBorder(),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  bool isManageStock() =>
      _listActionValue == Constants.update || _listActionValue == Constants.add;
}
