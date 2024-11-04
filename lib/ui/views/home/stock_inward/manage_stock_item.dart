import 'package:clinic_solution/core/utils/toast_utils.dart';
import 'package:clinic_solution/ui/views/home/stock_inward/stock_inward_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/locale_key.dart';
import '../../../../core/utils/locale_provider.dart';
import '../../../../core/utils/responsive_text_util.dart';
import '../../../../core/utils/size_utils.dart';
import '../../../../data/datasources/stock_model.dart';
import '../../../../main.dart';
import '../../../themes/text_styles.dart';
import '../../../widgets/common_button.dart';
import '../../../widgets/common_dropdown.dart';
import '../../../widgets/common_radio_group.dart';
import '../../../widgets/common_text.dart';
import '../../../widgets/common_textfield.dart';

class ManageStockItem extends StatefulWidget {
  final String? actionValue;
  final StockModel? stock;
  final String docId;
  final Function completeCallback;

  const ManageStockItem(
    this.completeCallback, {
    super.key,
    required this.actionValue,
    this.stock,
    required this.docId,
  });

  @override
  State<ManageStockItem> createState() => _ManageStockItemState();
}

class _ManageStockItemState extends State<ManageStockItem> {
  final StockInwardViewmodel viewModel = StockInwardViewmodel();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String? typeOfStock = Constants.medicine;
  bool isPowerOfSizeListEmpty = false;
  bool isResetPOSList = true;
  var localeProvider = LocaleProvider();
  var previousAction = "";
  String previousDocId="";

  @override
  Widget build(BuildContext context) {
    if (previousAction != widget.actionValue) {
      isResetPOSList = true;
      isPowerOfSizeListEmpty = false;
    }
    if(previousDocId!=widget.docId){
      isResetPOSList = true;
      isPowerOfSizeListEmpty = false;
    }
    if (widget.actionValue == Constants.add) {
      clearPOS();
      clearData();
      addDefaultPOS();
    } else {
      clearData();
      setUpdateStockData();
    }
    previousAction = widget.actionValue ?? "";
    return ChangeNotifierProvider(
        create: (_) => viewModel,
        child: Consumer<StockInwardViewmodel>(
            builder: (context, viewModel, child) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            addDefaultPOS();
          });

          return Column(
            children: [
              Center(
                  child: CommonText(
                text: widget.actionValue == Constants.update
                    ? AppLocalizations.of(context)!.updateStockOfData
                    : AppLocalizations.of(context)!.addStockOfData,
                color: Colors.lightBlue,
                height: getSize(35),
              )),
              Expanded(
                child: addOrUpdateItem(context),
              ),
            ],
          );
        }));
  }

  void setUpdateStockData() {
    final stock = widget.stock;

    print("DOCID: ${widget.docId}, STOCK DATA: ${stock.toString()}");
    if (stock != null && isResetPOSList) {
      previousDocId=widget.docId;
      viewModel.onVisibilityChanged(stock.visibility);
      viewModel.quntTabletCnt.text = stock.quantityTablets ?? "";

      viewModel.billNoCnt.text = stock.billNumber ?? "";
      viewModel.shortNameCnt.text = stock.shortName ?? "";
      viewModel.manufacturerCnt.text = stock.manufacturerName ?? "";
      viewModel.expiryDateController.text = stock.expiryDate ?? "";
      viewModel.minAvailCnt.text = stock.minimumAvailability ?? "";
      viewModel.maxAvailCnt.text = stock.maximumAvailability ?? "";
      viewModel.nearestDurationDayController.text =
          stock.nearestDurationDay ?? "";
      viewModel.brandNameCnt.text = stock.brandName ?? "";
      viewModel.purchasePersonCnt.text = stock.purchasingPerson ?? "";
      viewModel.containsMedicineCnt.text = stock.containsMedicine ?? "";
      viewModel.dateOfPurchaseController.text = stock.dateOfPurchase ?? "";
      viewModel.quntMedicineCnt.text = stock.quantityMedicine ?? "";
      viewModel.quntBoxCnt.text = stock.quantityBox ?? "";
      viewModel.quntTabletCnt.text = stock.quantityTablets ?? "";
      viewModel.onTypeOfFormChanged(stock.formType);
      viewModel.colorContentCnt.text = stock.colorOfContent ?? "";
      typeOfStock = stock.typeOfStock ?? Constants.medicine;

      if (stock.posContentName?.isNotEmpty == true &&
          stock.posContentSize?.isNotEmpty == true &&
          stock.posContentName?.length == stock.posContentSize?.length) {
        clearPOS();
        for (var i = 0; i < (stock.posContentName!.length); i++) {
          addPowerOfSize(
              name: stock.posContentName?[i] ?? "",
              size: stock.posContentSize?[i] ?? "0");
        }
      }
    }
  }

  void clearPOS() {
    if (isResetPOSList) {
      viewModel.clearPowerOfSize();
    }
  }

  void clearData() {
    if (isResetPOSList) {
      viewModel.clearData();
    }
  }

  void addDefaultPOS() {
    if (!isPowerOfSizeListEmpty) {
      addPowerOfSize();
      isPowerOfSizeListEmpty = true;
    }
  }

  Widget addOrUpdateItem(BuildContext context) {
    // var localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    return Form(
        key: _formKey,
        child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 10),
            children: [
              CommonRadioGroup<String>(
                title: AppLocalizations.of(context)!.typeOfStock,
                options: const [Constants.medicine, Constants.others],
                selectedValue: typeOfStock,
                onChanged: (value) {
                  setState(() {
                    typeOfStock = value;
                  });
                },
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
                controller: viewModel.purchasePersonCnt,
                keyboardType: TextInputType.text,
                hintText: '',
                labelText:
                AppLocalizations.of(context)!.purchasingPersonOrStockist,
                prefixIcon: FontAwesomeIcons.person,
                //validator: Validator().validatePhone,
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
                controller: viewModel.dateOfPurchaseController,
                keyboardType: TextInputType.datetime,
                hintText: '',
                isReadOnly: true,
                labelText: AppLocalizations.of(context)!.dateOfPurchase,
                prefixIcon: Icons.date_range_rounded,
                //validator: Validator().validatePhone,
                onTap: () {
                  viewModel.selectDate(
                      context, viewModel.dateOfPurchaseController);
                },
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
                  viewModel.selectDate(
                      context, viewModel.nearestDurationDayController);
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
                          labelText:
                              AppLocalizations.of(context)!.tabletsOrStrips,
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

              managePOSUI(context),
              const SizedBox(height: 15.0),
              CommonDropdown<String>(
                label: AppLocalizations.of(context)!.formType,
                selectedItem: viewModel.typeOfForm ?? "",
                items: viewModel.formTypeList,
                onChanged: viewModel.onTypeOfFormChanged,
                validator: (value) => value == null
                    ? AppLocalizations.of(context)!.formType
                    : null,
                prefixIcon: Icons.medical_information,
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
                selectedItem: viewModel.stockVisibility ?? "",
                items: viewModel.visibilityList,
                onChanged: viewModel.onVisibilityChanged,
                validator: (value) => value == null
                    ? AppLocalizations.of(context)!.visibilityShowOrHide
                    : null,
                prefixIcon: Icons.visibility,
              ),
              const SizedBox(height: 15.0),
              CommonTextField(
                controller: viewModel.ratePurchaseCnt,
                keyboardType: TextInputType.text,
                hintText: '',
                labelText: AppLocalizations.of(context)!.rateOfPurchase,
                prefixIcon: Icons.currency_rupee,
                //validator: Validator().validatePhone,
              ),
              const SizedBox(height: 15.0),
              CommonTextField(
                controller: viewModel.mrpCnt,
                keyboardType: TextInputType.text,
                hintText: '',
                labelText: AppLocalizations.of(context)!.mrp,
                prefixIcon: Icons.currency_rupee,
                //validator: Validator().validatePhone,
              ),
              const SizedBox(height: 15.0),
              submitButton(context),
            ]));
  }

  CommonButton submitButton(BuildContext context) {
    return CommonButton(
      onPressed: () async {
        if (viewModel.validateForm(_formKey)) {
          if (widget.actionValue == Constants.update) {
            await viewModel.updateStockData(typeOfStock!, widget.docId, () {
              showToast(AppLocalizations.of(navigatorKey.currentContext!)!
                  .stockUpdatedSuccessfully);
              widget.completeCallback();
            }, (e) {
              showToast(e.toString());
            });
          } else {
            await viewModel.addNewStockData(typeOfStock!, () {
              showToast(AppLocalizations.of(navigatorKey.currentContext!)!
                  .stockSavedSuccessfully);
              widget.completeCallback();
            }, (e) {
              showToast(e.toString());
            });
          }
          isPowerOfSizeListEmpty = false;
          isResetPOSList = true;
          setState(() {});
        }
      },
      text: widget.actionValue == Constants.update
          ? AppLocalizations.of(context)!.update
          : AppLocalizations.of(context)!.submit,
    );
  }

  Column managePOSUI(BuildContext context) {
    return Column(
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
                  isResetPOSList = false;
                  addPowerOfSize();
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
    );
  }

  void addPowerOfSize({String name = "", String size = "0"}) {
    setState(() {
      print(
          "addPowerOfSize before clicked: posNameListController:${viewModel.posNameListController.length},posSizeListController:${viewModel.posSizeListController.length},powerOfSizeWidgetList:${viewModel.powerOfSizeWidgetList.length}");
      viewModel.posNameListController.add(TextEditingController(text: name));
      viewModel.posSizeListController.add(TextEditingController(text: size));
      viewModel.powerOfSizeWidgetList
          .add(buildPowerOfSize(viewModel.powerOfSizeWidgetList.length));
      print(
          "addPowerOfSize after clicked: posNameListController:${viewModel.posNameListController.length},posSizeListController:${viewModel.posSizeListController.length},powerOfSizeWidgetList:${viewModel.powerOfSizeWidgetList.length}");
    });
  }

  Widget buildPowerOfSize(int index) {
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
                labelText: AppLocalizations.of(navigatorKey.currentContext!)!
                    .contentName,
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
                labelText:
                    AppLocalizations.of(navigatorKey.currentContext!)!.size,
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
