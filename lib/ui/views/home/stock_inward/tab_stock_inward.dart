import 'package:clinic_solution/core/utils/size_utils.dart';
import 'package:clinic_solution/ui/views/home/stock_inward/stock_inward_viewmodel.dart';
import 'package:clinic_solution/ui/widgets/common_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/locale_provider.dart';
import '../../../../core/utils/responsive_text_util.dart';
import '../../../../data/datasources/stock_model.dart';
import '../../../../main.dart';
import '../../../themes/text_styles.dart';
import '../../../widgets/common_button.dart';
import '../../../widgets/common_dropdown.dart';
import '../../../widgets/common_radio_group.dart';
import '../../../widgets/common_textfield.dart';

class TabStockInward extends StatefulWidget {
  //TabStockInward({super.key});

  @override
  State<TabStockInward> createState() => _TabStockInwardState();
}

class _TabStockInwardState extends State<TabStockInward> {
  var localeProvider = LocaleProvider();
  bool isPowerOfSizeListEmpty = false;
  String? _selectedOption;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize _selectedOption here where AppLocalizations is available
    _selectedOption ??= AppLocalizations.of(context)!.medicine;
  }

  @override
  Widget build(BuildContext context) {
    var localeProvider = Provider.of<LocaleProvider>(context, listen: false);

    return ChangeNotifierProvider(
      create: (_) => StockInwardViewmodel(),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: Consumer<StockInwardViewmodel>(
            builder: (context, viewModel, child) {
              if (!isPowerOfSizeListEmpty) {
                viewModel.posNameListController
                    .add(TextEditingController(text: ""));
                viewModel.posSizeListController
                    .add(TextEditingController(text: "0"));
                viewModel.powerOfSizeWidgetList.add(buildPowerOfSize(viewModel,
                    context, viewModel.powerOfSizeWidgetList.length));
                isPowerOfSizeListEmpty = true;
              }

              return Form(
                  key: _formKey,
                  child: isTabletOrDesktop(context)
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: viewListOfData(context, viewModel)),
                            const VerticalDivider(
                              color: Colors.grey,
                              thickness: 1, // Thickness of the divider
                              width: 20, // Space around the divider
                            ),

                            /*isTableOrDesktop(context)
                    ? GridView(
                        gridDelegate:  SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          // Show 2 columns on tablets and larger devices
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio:
                          (MediaQuery.of(context).size.width) /
                              (MediaQuery.of(context).size.height / 5), // Adjust the height/width ratio as needed
                        ),
                        children: stockListOfContent(context, viewModel).map((widget) {
                          return IntrinsicHeight( // Ensures each item adjusts to its content height
                            child: widget,
                          );
                        }).toList(),
                      )
                    :*/
                            Expanded(
                                child: addOrUpdateData(context, viewModel)),
                          ],
                        )
                      : Column(
                          children: [
                            Expanded(child: viewListOfData(context, viewModel)),
                            const SizedBox(height: 15.0),
                            const Divider(),
                            const SizedBox(height: 15.0),
                            Expanded(
                                child: addOrUpdateData(context, viewModel)),
                          ],
                        ));
            },
          ),
        ),
      ),
    );
  }

  Widget viewListOfData(BuildContext context, StockInwardViewmodel viewModel) {
    return Column(
      children: [
        Center(
            child: CommonText(
          text: AppLocalizations.of(context)!.listOfStockData,
          color: Colors.red,
          height: getSize(35),
        )),
        Expanded(
            child: StreamBuilder<QuerySnapshot>(
          stream: viewModel.stockStream,
          builder:
              (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
            if (snapshot.hasError) {
              return const Text('Something went wrong');
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Text("Loading");
            }

            return ListView(
              children: snapshot.data!.docs.map((DocumentSnapshot document) {
                // Convert the DocumentSnapshot to StockModel
                StockModel stock = StockModel.fromFirestore(
                    document as DocumentSnapshot<Map<String, dynamic>>, null);

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(
                      vertical: 8.0, horizontal: 10.0),
                  child: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Row for Stock details and Action icons (Update/Delete)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Expanded widget for the stock details text
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Short Name
                                  CommonText(
                                    text: (stock.shortName ?? 'No Short Name')
                                        .toUpperCase(),
                                    style: AppTextStyles.getBoldTextStyle(
                                        localeProvider.locale,
                                        fontSize: 16),
                                  ),
                                  const SizedBox(height: 4),

                                  // Bill Number
                                  CommonText(
                                      fontSize: 14,
                                      text:
                                          'Bill Number: ${stock.billNumber ?? 'N/A'}'),
                                  const SizedBox(height: 4),

                                  // Expiry Date and Manufacturer
                                  CommonText(
                                      fontSize: 14,
                                      text:
                                          'Expiry Date: ${stock.expiryDate ?? 'No Expiry Date'}'),
                                  CommonText(
                                      fontSize: 14,
                                      text:
                                          'Manufacturer: ${stock.manufacturerName ?? 'No Manufacturer'}'),

                                  const SizedBox(height: 4),

                                  // Availability
                                  CommonText(
                                      fontSize: 14,
                                      text:
                                          'Availability: Min ${stock.minimumAvailability ?? 'N/A'} - Max ${stock.maximumAvailability ?? 'N/A'}'),

                                  // Quantity details
                                  CommonText(
                                      fontSize: 14,
                                      text:
                                          'Quantity: ${stock.quantityMedicine ?? 'N/A'}-Medicines OR ${stock.quantityTablets ?? 'N/A'}-Tablets OR ${stock.quantityBox ?? 'N/A'}-Boxes'),
                                ],
                              ),
                            ),
                            Column(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit,
                                      color: Colors.lightBlue),
                                  onPressed: () {
                                    // Add your update logic here
                                    print(
                                        'Update clicked for ${stock.shortName}');
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () {
                                    print(
                                        'Delete clicked for ${stock.shortName}');
                                    viewModel.deleteStockData(document.id);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            AppLocalizations.of(context)!
                                                .stockDeletedSuccessfully),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),

                        const Divider(),

                        // Trailing Section for Purchase date and Stock Type
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Purchase Date
                            CommonText(
                              text:
                                  'Purchased: ${stock.dateOfPurchase ?? 'Unknown'}',
                              style: AppTextStyles.getRegularTextStyle(
                                      localeProvider.locale,
                                      fontSize: 14)
                                  .copyWith(color: Colors.grey[600]),
                            ),
                            // Type of Stock (Medicine or Other)
                            CommonText(
                              fontSize: 14,
                              text: stock.typeOfStock == 'Medicine'
                                  ? 'Medicine'
                                  : 'Other',
                              color: stock.typeOfStock == 'Medicine'
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ))
      ],
    );
  }

  Widget addOrUpdateData(BuildContext context, StockInwardViewmodel viewModel) {
    return Column(
      children: [
        Center(
            child: CommonText(
          text: AppLocalizations.of(context)!.addStockOfData,
          color: Colors.lightBlue,
          height: getSize(35),
        )),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 10),
            children: addOrUpdateContent(context, viewModel),
          ),
        ),
      ],
    );
  }

  List<Widget> addOrUpdateContent(
      BuildContext context, StockInwardViewmodel viewModel) {
    return [
      CommonRadioGroup<String>(
        title: AppLocalizations.of(context)!.typeOfStock,
        options: [
          AppLocalizations.of(context)!.medicine,
          AppLocalizations.of(context)!.others
        ],
        labels: [
          AppLocalizations.of(context)!.medicine,
          AppLocalizations.of(context)!.others
        ],
        // Labels for each radio
        selectedValue: _selectedOption,
        onChanged: (value) {
          setState(() {
            _selectedOption = value;
          });
        },
      ),
      const SizedBox(height: 15.0),
      CommonTextField(
        controller: viewModel.billNoCnt,
        keyboardType: TextInputType.text,
        hintText: '',
        labelText: AppLocalizations.of(context)!.billNo,
        prefixIcon: Icons.inventory_outlined,
        //validator: Validator().validatePhone,
      ),
      const SizedBox(height: 15.0),
      CommonTextField(
        controller: viewModel.brandNameCnt,
        keyboardType: TextInputType.text,
        hintText: '',
        labelText: AppLocalizations.of(context)!.brandName,
        prefixIcon: Icons.branding_watermark,
        //validator: Validator().validatePhone,
      ),
      const SizedBox(height: 15.0),
      CommonTextField(
        controller: viewModel.shortNameCnt,
        keyboardType: TextInputType.text,
        hintText: '',
        labelText: AppLocalizations.of(context)!.shortName,
        prefixIcon: Icons.short_text,
        //validator: Validator().validatePhone,
      ),
      const SizedBox(height: 15.0),
      CommonTextField(
        controller: viewModel.manufacturerCnt,
        keyboardType: TextInputType.text,
        hintText: '',
        labelText: AppLocalizations.of(context)!.manufacturerName,
        prefixIcon: Icons.precision_manufacturing,
        //validator: Validator().validatePhone,
      ),
      const SizedBox(height: 15.0),
      CommonTextField(
        controller: viewModel.expiryDateController,
        keyboardType: TextInputType.datetime,
        labelText: AppLocalizations.of(context)!.expiryDate,
        hintText: '',
        isReadOnly: true,
        prefixIcon: Icons.calendar_today,
        //validator: Validator().validateName,
        onTap: () {
          viewModel.selectDate(context, viewModel.expiryDateController);
        },
      ),
      const SizedBox(height: 15.0),

      CommonTextField(
        controller: viewModel.minAvailCnt,
        keyboardType: TextInputType.number,
        labelText: AppLocalizations.of(context)!.minimumAvailability,
        hintText: '',
        prefixIcon: Icons.hourglass_empty,
        //validator: Validator().validateEmail,
      ),
      const SizedBox(height: 15.0),

      // Password Field
      CommonTextField(
        controller: viewModel.maxAvailCnt,
        keyboardType: TextInputType.number,
        hintText: '',
        labelText: AppLocalizations.of(context)!.maximumAvailability,
        prefixIcon: Icons.hourglass_empty,
        //validator: Validator().validatePassword,
      ),
      const SizedBox(height: 15.0),

      // Phone Field
      CommonTextField(
        controller: viewModel.nearestDurationDayController,
        keyboardType: TextInputType.datetime,
        hintText: '',
        isReadOnly: true,
        labelText: AppLocalizations.of(context)!.nearestDurationDays,
        prefixIcon: Icons.calendar_month,
        //validator: Validator().validatePhone,
        onTap: () {
          viewModel.selectDate(context, viewModel.nearestDurationDayController);
        },
      ),
      const SizedBox(height: 15.0),
      CommonTextField(
        controller: viewModel.purchasePersonCnt,
        keyboardType: TextInputType.text,
        hintText: '',
        labelText: AppLocalizations.of(context)!.purchasingPersonOrStockist,
        prefixIcon: FontAwesomeIcons.person,
        //validator: Validator().validatePhone,
      ),
      const SizedBox(height: 15.0),
      CommonTextField(
        controller: viewModel.containsMedicineCnt,
        keyboardType: TextInputType.text,
        hintText: '',
        labelText: AppLocalizations.of(context)!.containsOfMedicine,
        prefixIcon: FontAwesomeIcons.pills,
        //validator: Validator().validatePhone,
      ),
      const SizedBox(height: 15.0),
      CommonTextField(
        controller: viewModel.dateOfPurchaseController,
        keyboardType: TextInputType.datetime,
        hintText: '',
        isReadOnly: true,
        labelText: AppLocalizations.of(context)!.dateOfPurchase,
        prefixIcon: Icons.date_range_rounded,
        //validator: Validator().validatePhone,
        onTap: () {
          viewModel.selectDate(context, viewModel.dateOfPurchaseController);
        },
      ),
      const SizedBox(height: 15.0),
      Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CommonText(
            text: AppLocalizations.of(context)!.quantity,
            fontSize: 16,
            height: 30,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: CommonTextField(
                  controller: viewModel.quntMedicineCnt,
                  keyboardType: TextInputType.text,
                  hintText: '',
                  labelText: AppLocalizations.of(context)!.medicine,
                  //validator: Validator().validatePhone,
                  height: getSize(40),
                  fontSize: getSize(16),
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: CommonTextField(
                  controller: viewModel.quntTabletCnt,
                  keyboardType: TextInputType.text,
                  hintText: '',
                  labelText: AppLocalizations.of(context)!.tabletsOrStrips,
                  //validator: Validator().validatePhone,
                  height: getSize(40),
                  fontSize: getSize(16),
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: CommonTextField(
                  controller: viewModel.quntBoxCnt,
                  keyboardType: TextInputType.text,
                  hintText: '',
                  labelText: AppLocalizations.of(context)!.box,
                  //validator: Validator().validatePhone,
                  height: getSize(40),
                  fontSize: getSize(16),
                ),
              ),
            ],
          ),
        ],
      ),

      const SizedBox(height: 15.0),

      Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: getSize(25),
            child: Row(
              children: [
                CommonText(
                  text: AppLocalizations.of(context)!.powerOfSize,
                  fontSize: 16,
                  height: 30,
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    addRow(viewModel, context);
                  },
                  child: CommonText(
                    text: AppLocalizations.of(context)!.addMoreContent,
                    style:
                        AppTextStyles.getRegularTextStyle(localeProvider.locale)
                            .copyWith(
                                decoration: TextDecoration.underline,
                                fontSize:
                                    ResponsiveTextUtil.getResponsiveFontSize(
                                        navigatorKey.currentContext!,
                                        baseFontSize: AppTextStyles.getFontSize(
                                            localeProvider.locale, 16))),
                  ),
                ),
              ],
            ),
          ),
          ListView.builder(
            shrinkWrap: true,
            itemCount: viewModel.powerOfSizeWidgetList.length,
            itemBuilder: (context, index) {
              return Wrap(children: [viewModel.powerOfSizeWidgetList[index]]);
            },
          ),
        ],
      ),
      const SizedBox(height: 15.0),
      CommonTextField(
        controller: viewModel.formTypeCnt,
        keyboardType: TextInputType.text,
        hintText: '',
        labelText: AppLocalizations.of(context)!.formType,
        prefixIcon: Icons.medical_information,
        //validator: Validator().validatePhone,
      ),
      const SizedBox(height: 15.0),

      CommonTextField(
        controller: viewModel.colorContentCnt,
        keyboardType: TextInputType.text,
        hintText: '',
        labelText: AppLocalizations.of(context)!.colorOfContent,
        prefixIcon: Icons.color_lens,
        //validator: Validator().validatePhone,
      ),
      const SizedBox(height: 15.0),
      CommonDropdown<String>(
        label: AppLocalizations.of(context)!.visibilityShowOrHide,
        items: viewModel.visibilityList,
        onChanged: viewModel.onVisibilityChanged,
        validator: (value) => value == null
            ? AppLocalizations.of(context)!.visibilityShowOrHide
            : null,
        prefixIcon: Icons.visibility,
      ),
      const SizedBox(height: 15.0),
      CommonButton(
        onPressed: () async {
          if (viewModel.validateForm(_formKey)) {
            await viewModel.addNewStockData(_selectedOption!);
            isPowerOfSizeListEmpty = false;
            setState(() {});
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content:
                    Text(AppLocalizations.of(context)!.stockSavedSuccessfully),
              ),
            );
          }
        },
        text: AppLocalizations.of(context)!.submit,
      ),
    ];
  }

  void addRow(StockInwardViewmodel viewModel, BuildContext context) {
    setState(() {
      viewModel.posNameListController.add(TextEditingController(text: ""));
      viewModel.posSizeListController.add(TextEditingController(text: "0"));
      viewModel.powerOfSizeWidgetList.add(buildPowerOfSize(
          viewModel, context, viewModel.powerOfSizeWidgetList.length));
    });
  }

  Widget buildPowerOfSize(
      StockInwardViewmodel viewModel, BuildContext context, int index) {
    return Column(
      children: [
        const SizedBox(height: 15.0),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: CommonTextField(
                controller: viewModel.posNameListController[index],
                keyboardType: TextInputType.text,
                hintText: '',
                labelText: AppLocalizations.of(context)!.contentName,
                //validator: Validator().validatePhone,
                height: getSize(40),
                fontSize: getSize(16),
              ),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: CommonTextField(
                controller: viewModel.posSizeListController[index],
                keyboardType: TextInputType.text,
                hintText: '',
                labelText: AppLocalizations.of(context)!.size,
                //validator: Validator().validatePhone,
                height: getSize(40),
                fontSize: getSize(16),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
